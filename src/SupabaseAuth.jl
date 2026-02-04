module SupabaseAuth

using HTTP
using JSON3
using Dates

export SupabaseClient, SupabaseUser, SupabaseSession
export login, sign_up, sign_out, refresh_session, user, request
export start_auto_refresh, stop_auto_refresh
export is_expired, is_authenticated

const DEFAULT_LEEWAY = 60  
const MAX_RETRIES = 3      
const API_VERSION = "v1"


struct SupabaseClient
    url::String
    anon_key::String
    auth_url::String
    function SupabaseClient(url::String, anon_key::String)
        base_url = rstrip(url, '/')
        new(base_url, anon_key, "$base_url/auth/$API_VERSION")
    end
end

struct SupabaseUser
    id::String
    email::String
    role::String
    last_sign_in_at::Union{String, Nothing}
    user_metadata::Dict{String, Any}
    app_metadata::Dict{String, Any}
end

mutable struct SupabaseSession
    access_token::String
    refresh_token::String
    expires_at::Int64       
    token_type::String
    user::Union{SupabaseUser, Nothing}
    refresh_task::Union{Task, Nothing} 
end

function SupabaseSession(access, refresh, expires, type, user)
    return SupabaseSession(access, refresh, expires, type, user, nothing)
end


function parse_user(data)
    return SupabaseUser(
        string(data.id),
        string(get(data, :email, "")),
        string(get(data, :role, "authenticated")),
        get(data, :last_sign_in_at, nothing),
        get(data, :user_metadata, Dict{String,Any}()),
        get(data, :app_metadata, Dict{String,Any}())
    )
end

function parse_session(data)
    user_obj = haskey(data, :user) ? parse_user(data.user) : nothing
    
    return SupabaseSession(
        string(data.access_token),
        string(data.refresh_token),
        Int64(time() + data.expires_in),
        string(data.token_type),
        user_obj
    )
end

function is_expired(session::SupabaseSession; leeway=DEFAULT_LEEWAY)
    return time() >= (session.expires_at - leeway)
end

is_authenticated(session::SupabaseSession) = !isnothing(session.access_token) && !is_expired(session)

function api_request(client::SupabaseClient, method::String, path::String; body=nothing, token=nothing)
    url = "$(client.auth_url)$path"
    
    headers = Dict(
        "apikey" => client.anon_key,
        "Content-Type" => "application/json"
    )
    
    if !isnothing(token)
        headers["Authorization"] = "Bearer $token"
    end

    request_body = isnothing(body) ? UInt8[] : JSON3.write(body)

    try
        response = HTTP.request(method, url, headers, request_body)
        return JSON3.read(response.body)
    catch e
        if e isa HTTP.StatusError
            try
                err_json = JSON3.read(e.response.body)
                msg = get(err_json, :msg, get(err_json, :error_description, "Unknown Error"))
                error("Supabase API ($((e.status))): $msg")
            catch
                error("Supabase API ($((e.status))): $(String(e.response.body))")
            end
        else
            rethrow(e)
        end
    end
end

function sign_up(client::SupabaseClient, email::String, password::String; data::Dict=Dict())
    payload = Dict("email" => email, "password" => password, "data" => data)
    response = api_request(client, "POST", "/signup", body=payload)
    if haskey(response, :access_token)
        return parse_session(response)
    elseif haskey(response, :id)
        return parse_user(response)
    else
        return response 
    end
end

function login(client::SupabaseClient, email::String, password::String)
    payload = Dict("email" => email, "password" => password)
    response = api_request(client, "POST", "/token?grant_type=password", body=payload)
    return parse_session(response)
end

function sign_out(client::SupabaseClient, session::SupabaseSession)
    try
        api_request(client, "POST", "/logout", token=session.access_token)
    catch e
        @warn "Logout on server failed (token might be dead already): $e"
    end
    session.access_token = ""
    session.refresh_token = ""
    stop_auto_refresh(session)
    return true
end

function refresh_session(client::SupabaseClient, session::SupabaseSession)
    payload = Dict("refresh_token" => session.refresh_token)
    response = api_request(client, "POST", "/token?grant_type=refresh_token", body=payload)
    new_data = parse_session(response)
    session.access_token = new_data.access_token
    session.refresh_token = new_data.refresh_token
    session.expires_at = new_data.expires_at
    session.user = new_data.user
    
    return session
end

function request(client::SupabaseClient, session::SupabaseSession, method::String, endpoint::String, body=nothing)
    if is_expired(session)
        @info "Token expired during request. Attempting synchronous refresh..."
        refresh_session(client, session)
    end
    url = "$(client.url)$endpoint"
    
    headers = Dict(
        "apikey" => client.anon_key,
        "Authorization" => "Bearer $(session.access_token)",
        "Content-Type" => "application/json"
    )

    req_body = isnothing(body) ? UInt8[] : JSON3.write(body)
    resp = HTTP.request(method, url, headers, req_body)
    return JSON3.read(resp.body)
end

function start_auto_refresh(client::SupabaseClient, session::SupabaseSession)
    stop_auto_refresh(session)

    session.refresh_task = @async begin
        while true
            try
                time_to_wait = (session.expires_at - DEFAULT_LEEWAY) - time()
                
                if time_to_wait > 0
                    sleep(time_to_wait)
                end
                success = false
                for attempt in 1:MAX_RETRIES
                    try
                        @debug "Refreshing session (Attempt $attempt)..."
                        refresh_session(client, session)
                        success = true
                        break 
                    catch e
                        backoff = 2.0 ^ attempt
                        @warn "Refresh failed. Retrying in $(backoff)s..." exception=e
                        sleep(backoff)
                    end
                end

                if !success
                    @error "FATAL: Could not refresh Supabase session after $MAX_RETRIES attempts. User logged out."
                    break 
                end

            catch e
                if e isa InterruptException
                    break
                else
                    @error "Unexpected error in refresh loop" exception=e
                    sleep(10) 
                end
            end
        end
    end
    
    println("Auto-refresh background task started.")
end

function stop_auto_refresh(session::SupabaseSession)
    if !isnothing(session.refresh_task) && !istaskdone(session.refresh_task)
        schedule(session.refresh_task, InterruptException(), error=true)
    end
    session.refresh_task = nothing
end

macro profile_api(ex)
    return quote
        local start_time = time_ns()
        local result = $(esc(ex)) 
        local end_time = time_ns()
        
        local duration_ms = (end_time - start_time) / 1e6
        
        printstyled("[Supabase] API Call took: ", color=:cyan)
        printstyled(round(duration_ms, digits=2), " ms\n", color=:green, bold=true)
        
        result 
    end
end

export @profile_api
macro safe_task(ex)
    return quote
        @async begin
            try
                $(esc(ex))
            catch e
                @error "Background Task Failed!" exception=(e, catch_backtrace())
            end
        end
    end
end
export @safe_task
end 