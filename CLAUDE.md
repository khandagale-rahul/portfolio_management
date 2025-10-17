# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Portfolio Management** Rails 8 application for managing trading API configurations across multiple brokers (Zerodha, Upstox, Angel One). The app provides user authentication, allows users to securely store and manage their trading API credentials, and implements OAuth flows for broker authorization. It also manages trading instruments (stocks, options, futures) from multiple brokers using a unified data model.

## Technology Stack

- **Rails**: 8.0.2+
- **Ruby**: 3.4.5
- **Database**: PostgreSQL (primary), SQLite3 (cache, queue, cable)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5.3.3, HAML templates
- **Background Jobs**: Sidekiq with Sidekiq-cron for scheduled tasks
- **WebSocket**: Faye-WebSocket with EventMachine for real-time market data
- **Message Protocol**: Google Protobuf for binary data decoding
- **Cache/State**: Redis for WebSocket connection state management
- **Testing**: RSpec with FactoryBot and Faker
- **Deployment**: Kamal (Docker-based)

## Essential Commands

### Database
```bash
# Setup database
bin/rails db:create db:migrate

# Reset database
bin/rails db:reset

# Run migrations
bin/rails db:migrate

# Rollback migration
bin/rails db:rollback
```

### Server
```bash
# Start Rails server
bin/rails server

# Start with specific environment
RAILS_ENV=production bin/rails server
```

### Testing
```bash
# Run all specs
bundle exec rspec

# Run specific spec file
bundle exec rspec spec/models/api_configuration_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/api_configuration_spec.rb:10

# Run controller specs
bundle exec rspec spec/controllers/

# Run model specs
bundle exec rspec spec/models/
```

### Code Quality
```bash
# Run Rubocop
bundle exec rubocop

# Auto-correct Rubocop offenses
bundle exec rubocop -A

# Security scan with Brakeman
bundle exec brakeman
```

### Assets
```bash
# Build CSS (using cssbundling-rails)
bin/rails css:build

# Watch CSS for changes
bin/rails css:watch
```

### Console
```bash
# Rails console
bin/rails console

# Production console
RAILS_ENV=production bin/rails console

# Import instruments (in console)
UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")
ZerodhaInstrument.import_instruments(api_key: "your_key", access_token: "your_token")
```

### Background Jobs (Sidekiq)
```bash
# Start Sidekiq worker
bundle exec sidekiq

# Start Sidekiq with specific queue
bundle exec sidekiq -q market_data

# View Sidekiq web UI (mount in routes.rb first)
# Visit /sidekiq in browser
```

### Redis
```bash
# Connect to Redis CLI
redis-cli

# Check WebSocket service status
redis-cli GET upstox:market_data:status

# View connection stats
redis-cli GET upstox:market_data:connection_stats
```

### Generators
```bash
# Generate model
bin/rails generate model ModelName

# Generate controller
bin/rails generate controller ControllerName

# Generate migration
bin/rails generate migration MigrationName
```

## Architecture & Key Concepts

### Multi-Database Configuration

The application uses a **multi-database setup**:
- **Primary database** (PostgreSQL): Users, Sessions, API Configurations, Instruments
- **Cache database** (SQLite): Solid Cache storage at `storage/equity_cache.sqlite3`
- **Queue database** (SQLite): Solid Queue jobs at `storage/equity_queue.sqlite3`
- **Cable database** (SQLite): Action Cable at `storage/equity_cable.sqlite3`

Each non-primary database has its own migration path (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`).

**Time Zone**: The application is configured for "Kolkata" timezone (IST) in `config/application.rb`.

### Authentication System

Custom session-based authentication implemented in `app/controllers/concerns/Authentication` module:
- **Session management**: Database-backed sessions (not Rails default session cookies)
- **Current context**: Uses `Current.session` (thread-local) to track authenticated user
- **Cookie-based**: Signed, permanent cookies with `httponly` and `same_site: :lax`
- **Controllers**: Include `Authentication` concern, use `allow_unauthenticated_access` to skip auth

Key methods in Authentication concern:
- `start_new_session_for(user)` - Creates session after login
- `terminate_session` - Destroys session on logout
- `require_authentication` - Before action to enforce auth
- `after_authentication_url` - Redirect after login with return_to support

### Models & Relationships

**User** (`app/models/user.rb`):
- `has_secure_password` for bcrypt authentication
- `has_many :sessions, dependent: :destroy`
- `has_many :api_configurations, dependent: :destroy`
- Email normalization (strip + downcase)
- Phone validation: 10-15 digits, optional `+` prefix

**ApiConfiguration** (`app/models/api_configuration.rb`):
- Enum for `api_name`: `{ zerodha: 1, upstox: 2, angel_one: 3 }`
- Unique constraint: One API config per `[user_id, api_name]` combination
- Stores API credentials: `api_key` and `api_secret`
- OAuth token management: `access_token`, `token_expires_at`, `oauth_authorized_at`, `oauth_state`
- `redirect_uri` field for OAuth callback URL
- Helper methods for OAuth state:
  - `oauth_authorized?` - Returns true if authorized with valid access token
  - `token_expired?` - Checks if `token_expires_at` is in the past
  - `requires_reauthorization?` - Returns true if not authorized or token expired
  - `oauth_status` - Returns string: "Not Authorized", "Token Expired", or "Authorized"
  - `oauth_status_badge_class` - Returns Bootstrap badge class for UI: "bg-secondary", "bg-danger", or "bg-success"

**Session** (`app/models/session.rb`):
- Tracks `user_agent` and `ip_address`
- Belongs to User

**Instrument** (`app/models/instrument.rb`):
- Base model using **Single Table Inheritance (STI)** pattern
- Stores trading instruments: stocks, options, futures, etc.
- Fields: `type`, `symbol`, `name`, `exchange`, `segment`, `identifier`, `tick_size`, `lot_size`
- `raw_data` JSONB field for broker-specific metadata (indexed with GIN)
- Subclasses: `UpstoxInstrument`, `ZerodhaInstrument`

### Routes Structure

- **Root**: Dashboard (`dashboard#index`)
- **Session**: Singular resource (`resource :session`) for login/logout
- **Passwords**: Token-based password reset (`resources :passwords, param: :token`)
- **API Configurations**: Standard CRUD (`resources :api_configurations`)
- **Instruments**: Read-only index (`resources :instruments, only: [:index]`) for viewing trading instruments
- **Upstox OAuth**:
  - `POST /upstox/oauth/authorize/:id` - Initiates OAuth flow
  - `GET /upstox/oauth/callback` - Handles OAuth callback
- **Zerodha OAuth**:
  - `POST /zerodha/oauth/authorize/:id` - Initiates OAuth flow
  - `GET /zerodha/oauth/callback` - Handles OAuth callback

### Generator Configuration

RSpec is configured as the default test framework with:
- **Fixtures**: Enabled
- **View specs**: Disabled
- **Helper specs**: Disabled
- **Routing specs**: Disabled
- **Controller specs**: Enabled
- **Request specs**: Disabled
- **Factory replacement**: FactoryBot at `spec/factories`

### Background Jobs & Scheduled Tasks

**Sidekiq Configuration** ([config/initializers/sidekiq.rb](config/initializers/sidekiq.rb)):
- Redis URL: `ENV["REDIS_URL"]` (default: `redis://localhost:6379/0`)
- Sidekiq-cron loads schedule from [config/schedule.yml](config/schedule.yml)

**Scheduled Jobs** (runs in IST timezone, Monday-Friday):
- **Start Market Data** (`Upstox::StartWebsocketConnectionJob`): 9:00 AM - Starts WebSocket connection
- **Stop Market Data** (`Upstox::StopWebsocketConnectionJob`): 3:30 PM - Stops WebSocket connection
- **Health Check** (`Upstox::HealthCheckWebsocketConnectionJob`): Every 5 min (9 AM-3 PM) - Monitors service health

**Job Queues**:
- `market_data` - Real-time market data streaming jobs
- `default` - General background jobs

**Alternative**: Solid Queue is available as Rails 8 native adapter (not currently used)

### Service Object Pattern

Services are organized by broker in namespaced directories (`app/services/upstox/`, etc.). Each broker should have its own module namespace:

```ruby
module Upstox
  class OauthService
    # Service methods here
  end
end
```

**Upstox OAuth Implementation** (`app/services/upstox/oauth_service.rb`):
- Service object pattern for OAuth operations
- `build_authorization_url(api_key, redirect_uri, state)` - Generates OAuth URL with CSRF protection
- `exchange_code_for_token(api_key, api_secret, code, redirect_uri)` - Exchanges auth code for access token
- Uses Upstox API v2 endpoints: `/v2/login/authorization/dialog` and `/v2/login/authorization/token`
- Returns structured hash with `:success`, `:access_token`, `:expires_at`, or `:error`

**Upstox OAuth Controller** (`app/controllers/upstox/oauth_controller.rb`):
- `authorize` action: Generates CSRF state token, stores in session and DB, redirects to Upstox
- `callback` action: Verifies state token, exchanges code for token, stores credentials
- Uses Rails session for temporary state storage during OAuth flow
- Scoped to `current_user.api_configurations`
- Controllers are namespaced under `app/controllers/upstox/` with module `Upstox`

**Zerodha OAuth Implementation** (`app/services/zerodha/oauth_service.rb`):
- Service object pattern for OAuth operations following Kite Connect v3 API
- `build_authorization_url(api_key, state)` - Generates Kite Connect login URL with state as redirect_params
- `exchange_token(api_key, api_secret, request_token)` - Exchanges request_token for access token
  - Generates SHA-256 checksum: `api_key + request_token + api_secret`
  - POSTs to `/session/token` endpoint
- `calculate_expiry()` - Calculates token expiry (6 AM next day IST)
- Uses Zerodha Kite Connect API endpoints: `https://kite.zerodha.com/connect/login` and `https://api.kite.trade/session/token`
- Returns structured hash with `:success`, `:access_token`, `:user_id`, or `:error`
- **Important**: Zerodha access tokens expire at 6 AM IST the next day (not 24 hours)

**Zerodha OAuth Controller** (`app/controllers/zerodha/oauth_controller.rb`):
- `authorize` action: Generates CSRF state token, stores in session and DB, redirects to Kite Connect
- `callback` action: Verifies state token, exchanges request_token for access token, stores credentials
- Uses Rails session for temporary state storage during OAuth flow
- Scoped to `current_user.api_configurations`
- Controllers are namespaced under `app/controllers/zerodha/` with module `Zerodha`

**Zerodha API Service** (`app/services/zerodha/api_service.rb`):
- Service object for Zerodha Kite API operations
- `instruments` - Fetches all instrument master data in CSV format
- Requires API key and access token for authentication
- Authorization header format: `token api_key:access_token`
- Base URL: `https://api.kite.trade`

### Real-Time Market Data WebSocket System

**Upstox WebSocket Service** ([app/services/upstox/websocket_service.rb](app/services/upstox/websocket_service.rb)):
- Connects to Upstox Market Data Feed v3 API for real-time trading data
- **Authorization**: Fetches WebSocket URL via `/v3/feed/market-data-feed/authorize` endpoint
- **Connection Management**:
  - Auto-reconnection with exponential backoff (max 10 attempts)
  - Heartbeat monitoring (checks every 30 seconds)
  - Connection health tracking with automatic recovery
  - State tracking via Redis: `upstox:market_data:status` (starting/running/stopping/stopped/error)
- **Subscription Modes**: `ltpc` (Last Traded Price), `full`, `option_greeks`, `full_d30`
- **Message Processing**: Binary Protobuf decoding via `lib/protobuf/upstox/MarketDataFeed_pb.rb`
- **EventMachine**: Runs in separate thread with EM reactor loop

**WebSocket Job Lifecycle** ([app/jobs/upstox/start_websocket_connection_job.rb](app/jobs/upstox/start_websocket_connection_job.rb)):
1. Validates authorized Upstox API configuration and access token
2. Spawns EventMachine thread with WebSocket service
3. Subscribes to NSE instruments (from `UpstoxInstrument` table)
4. Stores global reference in `$market_data_service` variable
5. Monitors stop signals from Redis every 60 seconds

**State Management** (Redis keys):
- `upstox:market_data:status` - Current service state
- `upstox:market_data:connection_stats` - JSON connection statistics
- `upstox:market_data:last_error` / `last_error_time` - Error tracking
- `upstox:market_data:last_connected_at` / `last_disconnected_at` - Connection history

**Protobuf Message Decoding**:
- Feed types: LTPC (Last Traded Price & Quantity), Full Feed (Market/Index), First Level with Greeks
- Parses market depth, OHLC, option greeks, bid/ask quotes
- Fallback to JSON/raw data if protobuf compilation unavailable

**Action Cable**: Solid Cable (database-backed adapter) available for server-to-client WebSocket broadcast

### Environment Variables

**Database** ([config/database.yml](config/database.yml)):
- `DATABASE_USERNAME` (default: "admin")
- `DATABASE_PASSWORD` (default: "admin")
- `DATABASE_HOST` (default: "localhost")
- `DATABASE_PORT` (default: "5432")
- `RAILS_MAX_THREADS` (default: 5)

**Redis** (Sidekiq & WebSocket state):
- `REDIS_URL` (default: "redis://localhost:6379/0")

## Important Notes

### Protobuf Message Compilation

The WebSocket service uses Protocol Buffers for efficient binary message decoding. The compiled Ruby file is at [lib/protobuf/upstox/MarketDataFeed_pb.rb](lib/protobuf/upstox/MarketDataFeed_pb.rb).

If you need to recompile from `.proto` file:
```bash
# Install protoc compiler first (platform-specific)
# Then compile:
protoc --ruby_out=lib/protobuf/upstox lib/protobuf/upstox/MarketDataFeed.proto
```

The service gracefully falls back to JSON/raw data if protobuf decoding fails, so compilation is optional but recommended for performance.

### Global State Variables

The application uses a global variable for WebSocket service management:
- `$market_data_service` - Holds the active `Upstox::WebsocketService` instance
- Created in `Upstox::StartWebsocketConnectionJob`
- Used for subscribing/unsubscribing to instruments while service is running
- Set to `nil` when service stops or encounters errors

### Security Considerations
- API credentials (`api_key`, `api_secret`) and OAuth tokens (`access_token`) are stored in plaintext in the database. Consider encrypting these with Rails encrypted attributes or a vault solution.
- Sessions are database-backed, providing better security than cookie-based sessions for this financial application.
- OAuth flow uses CSRF state tokens stored in both session and database for security.

### Testing with RSpec
- Use FactoryBot for test data: `spec/factories/`
- Controller specs are the primary spec type enabled
- Transaction-based fixtures are enabled for speed
- **Note**: Test database uses only the primary PostgreSQL database (not the multi-database setup used in development/production)

### Database Migrations
When creating migrations that affect non-primary databases, specify the migration path:
```bash
bin/rails generate migration CreateSomething --database=cache
```

### CSS Bundling
CSS is bundled via `cssbundling-rails`. After pulling changes, run `bin/rails css:build` if styles are missing.

### Single Table Inheritance (STI) Pattern
The `Instrument` model uses STI to handle broker-specific instruments:
- All instruments are stored in the `instruments` table
- The `type` column determines the subclass (`UpstoxInstrument`, `ZerodhaInstrument`)
- Use `Instrument.create(type: 'UpstoxInstrument', ...)` or `UpstoxInstrument.create(...)`
- Query all instruments: `Instrument.all`, or specific broker: `UpstoxInstrument.all`

**UpstoxInstrument** has a class method `import_from_upstox(exchange: "NSE_MIS")` that:
- Downloads and imports instrument data from Upstox API
- Handles gzipped JSON responses
- Uses `find_or_initialize_by` with `identifier` (instrument_key) for upserts
- Returns hash with `:imported`, `:skipped`, `:total` counts

**ZerodhaInstrument** has a class method `import_instruments(api_key:, access_token:)` that:
- Downloads and imports instrument data from Zerodha Kite API
- Requires API key and valid access token (unlike Upstox which uses public endpoint)
- Filters for NSE exchange and EQ (equity) instrument type only
- Parses CSV response and stores in unified Instrument table
- Uses `find_or_initialize_by` with `identifier` (instrument_token) for upserts
- Call from console: `ZerodhaInstrument.import_instruments(api_key: "your_key", access_token: "your_token")`

### Frontend & Views

- **Template engine**: HAML (`.html.haml` files)
- **Layout**: AdminLTE 3-based layout with sidebar navigation
- **CSS Framework**: Bootstrap 5.3.3 via CDN
- **Icons**: Bootstrap Icons and Font Awesome
- **Hotwire**: Turbo + Stimulus for SPA-like behavior
- **Turbo considerations**: When redirecting to external OAuth providers, disable Turbo on forms using `form: { data: { turbo: false } }` in `button_to` helpers

Example of disabling Turbo on button_to:
```haml
= button_to path, method: :post, form: { data: { turbo: false } } do
  Button text
```
