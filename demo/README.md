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

5. Visit the admin interface at http://localhost:4005/

## What's Included

- Simple Blog domain with Post resource
- Post has title, content, published flag, and word count calculation
- Backpex admin interface for managing posts
- A dashboard LiveView that is not a LiveResource but renders the admin layout
- Basic CRUD operations through the admin panel
- Article content sections demonstrating recursive embedded forms: repeated
  sections, repeated columns, and one singular target per column
- Selected attributes: `Post.content` has `select_by_default? false`, yet the
  admin shows it because it is a field. `Post`'s `TidyExcerpt` change reads
  `excerpt`, which the Articles index does not list, and runs for every index
  row when `can?/3` builds an update changeset
