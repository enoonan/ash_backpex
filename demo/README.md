# Ash Backpex Demo

A minimal demo application showcasing the integration between Ash Framework and Backpex.

## Setup

1. Install dependencies:
   ```bash
   mix deps.get
   ```

2. Create and migrate database:
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

3. Install assets dependencies:
   ```bash
   mix assets.setup
   ```

4. Start the server:
   ```bash
   mix phx.server
   ```

5. Visit the admin interface at http://localhost:4000/

## What's Included

- Simple Blog domain with Post resource
- Post has title, content, published flag, and word count calculation
- Backpex admin interface for managing posts
- Basic CRUD operations through the admin panel
