# Test Markdown Page

This is a test page to verify mdsvex is working correctly with direct `.md` file routing.

## Features

mdsvex allows us to:

- **Import Markdown as Svelte components** - `.md` files can be used directly as routes
- **Use Svelte components in Markdown** - Mix HTML, Markdown, and Svelte seamlessly
- **Apply layouts automatically** - This page uses the layout defined in `svelte.config.js`
- **Style with Tailwind Typography** - The `prose` classes provide beautiful typography

## How It Works

When you create a `+page.md` file in the routes directory, SvelteKit + mdsvex:

1. Processes the Markdown content
2. Applies the configured layout component
3. Renders it as a fully functional SvelteKit page
4. Provides all the benefits of SSG (static site generation)

## Code Example

```typescript
// Example TypeScript code
interface User {
  id: string
  name: string
  email: string
}

const users: User[] = [
  { id: '1', name: 'Alice', email: 'alice@example.com' },
  { id: '2', name: 'Bob', email: 'bob@example.com' }
]
```

## Lists and Formatting

**Ordered List:**
1. First step
2. Second step
3. Third step

**Unordered List:**
- Important point
- Another consideration
- Final note

## Navigation

From here you can navigate to:
- [Home Page](/)
- [Cases](/cases)
- [Notices](/notices)
- [Offenders](/offenders)
- [Agencies](/agencies)
- [Legislation](/legislation)

---

✅ **Phase 7A Complete**: mdsvex is successfully configured and rendering Markdown!
