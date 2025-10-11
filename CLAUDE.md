# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **Equity Trading** Rails 8 application for managing trading API configurations across multiple brokers (Zerodha, Upstox, Angel One). The app provides user authentication and allows users to securely store and manage their trading API credentials.

## Technology Stack

- **Rails**: 8.0.2+
- **Ruby**: Version managed via project
- **Database**: PostgreSQL (primary), SQLite3 (cache, queue, cable)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5.3.3, HAML templates
- **Background Jobs**: Sidekiq with Sidekiq-cron
- **WebSocket**: Faye-WebSocket with EventMachine
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
- **Primary database** (PostgreSQL): Users, Sessions, API Configurations
- **Cache database** (SQLite): Solid Cache storage at `storage/equity_cache.sqlite3`
- **Queue database** (SQLite): Solid Queue jobs at `storage/equity_queue.sqlite3`
- **Cable database** (SQLite): Action Cable at `storage/equity_cable.sqlite3`

Each non-primary database has its own migration path (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`).

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
- Enum for `api_name`: `{ zerodha: 1, upstock: 2, angel_one: 3 }`
- Unique constraint: One API config per `[user_id, api_name]` combination
- Stores encrypted credentials: `api_key` and `api_secret`

**Session** (`app/models/session.rb`):
- Tracks `user_agent` and `ip_address`
- Belongs to User

### Routes Structure

- **Root**: Dashboard (`dashboard#index`)
- **Session**: Singular resource (`resource :session`) for login/logout
- **Passwords**: Token-based password reset (`resources :passwords, param: :token`)
- **API Configurations**: Standard CRUD (`resources :api_configurations`)

### Generator Configuration

RSpec is configured as the default test framework with:
- **Fixtures**: Enabled
- **View specs**: Disabled
- **Helper specs**: Disabled
- **Routing specs**: Disabled
- **Controller specs**: Enabled
- **Request specs**: Disabled
- **Factory replacement**: FactoryBot at `spec/factories`

### Background Jobs Setup

- **Sidekiq**: For async job processing
- **Sidekiq-cron**: For scheduled/recurring jobs
- **Redis**: Required for Sidekiq (via `redis-client` gem)
- **Solid Queue**: Rails 8 native queue adapter (alternative to Sidekiq)

### WebSocket Infrastructure

- **Faye-WebSocket** + **EventMachine**: For WebSocket client connections (likely for real-time trading data)
- **Solid Cable**: Rails 8 database-backed Action Cable adapter

### Environment Variables

Database configuration expects:
- `DATABASE_USERNAME` (default: "admin")
- `DATABASE_PASSWORD` (default: "admin")
- `DATABASE_HOST` (default: "localhost")
- `DATABASE_PORT` (default: "5432")
- `RAILS_MAX_THREADS` (default: 5)

## Important Notes

### Security Considerations
- API credentials (`api_key`, `api_secret`) are stored in plaintext in the database. Consider encrypting these with Rails encrypted attributes or a vault solution.
- Sessions are database-backed, providing better security than cookie-based sessions for this financial application.

### Testing with RSpec
- Use FactoryBot for test data: `spec/factories/`
- Controller specs are the primary spec type enabled
- Transaction-based fixtures are enabled for speed

### Database Migrations
When creating migrations that affect non-primary databases, specify the migration path:
```bash
bin/rails generate migration CreateSomething --database=cache
```

### CSS Bundling
CSS is bundled via `cssbundling-rails`. After pulling changes, run `bin/rails css:build` if styles are missing.
