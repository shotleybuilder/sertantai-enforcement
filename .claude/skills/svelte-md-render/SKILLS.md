# Svelte Markdown Rendering Skill

**Purpose**: Guide for setting up and configuring mdsvex to render static Markdown pages in SvelteKit with proper pre-rendering, SEO, and styling.

**Stack**: SvelteKit + mdsvex + Tailwind Typography + Static Pre-rendering

**Last Updated**: 2025-11-20

---

## 📋 Overview

This skill covers the complete setup for rendering Markdown (`.md`) files as static pages in a SvelteKit application, including:
- mdsvex configuration with absolute path resolution
- Markdown layout components
- Frontmatter support for SEO meta tags
- Static pre-rendering at build time
- Tailwind Typography integration
- Production build troubleshooting

---

## 🎯 Use Cases

- **Static Content Pages**: About, Privacy Policy, Terms of Service, Documentation
- **SEO-Optimized Pages**: Pages that need to be crawled by search engines
- **Markdown-Based Content**: Content managed in Markdown format
- **Static Site Generation**: Pages that can be pre-rendered at build time

---

## 📦 Dependencies

### Required Packages

```json
{
  "devDependencies": {
    "@sveltejs/adapter-static": "^3.0.0",
    "@sveltejs/kit": "^2.0.0",
    "@tailwindcss/typography": "^0.5.19",
    "mdsvex": "^0.12.6",
    "svelte": "^4.2.0"
  }
}
```

### Installation

```bash
npm install -D mdsvex @tailwindcss/typography @sveltejs/adapter-static
```

---

## ⚙️ Configuration

### 1. SvelteKit Config (`svelte.config.js`)

**CRITICAL**: Use absolute path resolution for the layout component to avoid build errors.

```javascript
import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { mdsvex } from 'mdsvex';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

/** @type {import('mdsvex').MdsvexOptions} */
const mdsvexOptions = {
	extensions: ['.md'],
	layout: {
		// Use absolute path with resolve() - relative paths fail in production builds
		markdown: resolve(__dirname, './src/lib/layouts/markdown.svelte')
	}
};

/** @type {import('@sveltejs/kit').Config} */
const config = {
	// Add .md extension support
	extensions: ['.svelte', '.md'],

	// Add mdsvex to preprocessors
	preprocess: [vitePreprocess(), mdsvex(mdsvexOptions)],

	kit: {
		adapter: adapter({
			pages: 'build',
			assets: 'build',
			fallback: 'index.html',
			precompress: false,
			strict: true
		}),
		prerender: {
			// Handle missing assets gracefully during prerender
			handleHttpError: ({ path, referrer, message }) => {
				if (path === '/favicon.png' || path === '/favicon.ico') {
					return; // Ignore missing favicon
				}
				throw new Error(message);
			}
		}
	}
};

export default config;
```

**Key Points**:
- ✅ Use `resolve(__dirname, './src/lib/layouts/markdown.svelte')` for absolute paths
- ❌ DON'T use relative paths like `'./src/lib/layouts/markdown.svelte'` (fails in build)
- ✅ Add `.md` to `extensions` array
- ✅ Include mdsvex in `preprocess` array
- ✅ Add `handleHttpError` to ignore missing favicon warnings

---

### 2. Markdown Layout Component

**Location**: `/src/lib/layouts/markdown.svelte`

This component wraps all markdown content and provides consistent layout, navigation, and SEO.

```svelte
<script lang="ts">
	// mdsvex passes frontmatter as props using Svelte 4 syntax
	export let title = 'EHS Enforcement Tracker'
	export let description = 'UK enforcement data tracking platform'

	// Full title with site name
	$: fullTitle = title === 'EHS Enforcement Tracker' ? title : `${title} | EHS Enforcement Tracker`
</script>

<svelte:head>
	<title>{fullTitle}</title>
	<meta name="description" content={description} />
</svelte:head>

<div class="min-h-screen bg-gray-50">
	<!-- Header Navigation -->
	<nav class="bg-white border-b border-gray-200">
		<div class="container mx-auto px-4 py-4">
			<div class="flex items-center justify-between">
				<a href="/" class="text-xl font-bold text-gray-900">EHS Enforcement Tracker</a>
				<div class="flex gap-6">
					<a href="/cases" class="text-gray-600 hover:text-gray-900">Cases</a>
					<a href="/notices" class="text-gray-600 hover:text-gray-900">Notices</a>
					<a href="/offenders" class="text-gray-600 hover:text-gray-900">Offenders</a>
					<a href="/agencies" class="text-gray-600 hover:text-gray-900">Agencies</a>
					<a href="/legislation" class="text-gray-600 hover:text-gray-900">Legislation</a>
				</div>
			</div>
		</div>
	</nav>

	<!-- Main Content Area -->
	<main class="container mx-auto px-4 py-8 max-w-4xl">
		<!-- Markdown Content with Tailwind Typography -->
		<article class="prose prose-lg prose-slate max-w-none">
			<slot />
		</article>
	</main>

	<!-- Footer -->
	<footer class="bg-white border-t border-gray-200 mt-16">
		<div class="container mx-auto px-4 py-8">
			<div class="flex justify-between items-center text-sm text-gray-600">
				<p>&copy; {new Date().getFullYear()} EHS Enforcement Tracker</p>
				<div class="flex gap-6">
					<a href="/about" class="hover:text-gray-900">About</a>
					<a href="/privacy" class="hover:text-gray-900">Privacy</a>
					<a href="/terms" class="hover:text-gray-900">Terms</a>
					<a href="/contact" class="hover:text-gray-900">Contact</a>
				</div>
			</div>
		</div>
	</footer>
</div>
```

**Key Features**:
- Receives `title` and `description` from markdown frontmatter
- Applies SEO meta tags dynamically
- Includes site navigation and footer
- Uses Tailwind Typography (`prose` classes) for markdown styling
- `<slot />` renders the markdown content

---

### 3. Markdown Page Structure

**Location**: `/src/routes/about/+page.md` (example)

```markdown
---
title: About Us
description: Learn about EHS Enforcement - a comprehensive platform for UK environmental, health, and safety enforcement data
layout: markdown
---

# About EHS Enforcement

Welcome to EHS Enforcement, a comprehensive platform for collecting and managing UK environmental, health, and safety enforcement data.

## Our Mission

We provide transparency and insight into UK enforcement actions by collecting, processing, and presenting enforcement data from various regulatory agencies including HSE (Health and Safety Executive) and Environment Agency.

## What We Do

- Collect enforcement data from UK regulatory agencies
- Process and structure enforcement information
- Provide searchable database of cases and notices
- Generate reports and analytics on enforcement trends
- Maintain up-to-date information on offenders and violations

## Data Sources

Our data is collected from official government sources and regulatory agency websites, ensuring accuracy and reliability. We continuously monitor these sources to provide the most current information available.

<div class="bg-blue-50 border-l-4 border-blue-400 p-4 mt-8 rounded">
  <div class="flex items-start">
    <div class="flex-shrink-0">
      <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
      </svg>
    </div>
    <div class="ml-3">
      <p class="text-sm text-blue-700">
        This platform is currently in active development. Features and data may change as we continue to improve our services.
      </p>
    </div>
  </div>
</div>
```

**Frontmatter Fields**:
- `title` - Page title (used in `<title>` tag)
- `description` - SEO meta description
- `layout` - Must match the key in mdsvexOptions (e.g., `markdown`)

**Markdown Features**:
- Standard markdown syntax (headings, lists, links, etc.)
- HTML components can be embedded directly (for custom styling)
- Tailwind classes work in HTML elements

---

### 4. Pre-rendering Configuration

**Location**: `/src/routes/about/+page.ts` (for each markdown page)

```typescript
export const prerender = true
```

**Purpose**:
- Tells SvelteKit to generate static HTML at build time
- Page is served as static HTML (no SSR needed)
- Optimal for SEO and performance
- Works with adapter-static

**Required for**:
- All static content pages
- Pages that don't need dynamic server-side rendering
- SEO-optimized pages

---

## 🏗️ File Structure

```
frontend/
├── src/
│   ├── lib/
│   │   └── layouts/
│   │       └── markdown.svelte        # Layout wrapper for markdown
│   └── routes/
│       ├── about/
│       │   ├── +page.md              # Markdown content
│       │   └── +page.ts              # Pre-render config
│       ├── docs/
│       │   ├── +page.md
│       │   └── +page.ts
│       ├── privacy/
│       │   ├── +page.md
│       │   └── +page.ts
│       ├── terms/
│       │   ├── +page.md
│       │   └── +page.ts
│       └── support/
│           ├── +page.md
│           └── +page.ts
├── svelte.config.js                   # mdsvex configuration
└── package.json
```

---

## 🎨 Tailwind Typography Configuration

### Add Typography Plugin

**Location**: `tailwind.config.js` or `@tailwindcss/postcss` config

```javascript
module.exports = {
  plugins: [
    require('@tailwindcss/typography'),
  ],
}
```

### Prose Classes

Apply to the markdown content container:

```html
<article class="prose prose-lg prose-slate max-w-none">
  <slot />
</article>
```

**Available Modifiers**:
- `prose-sm` - Small text
- `prose-base` - Base size (default)
- `prose-lg` - Large text
- `prose-xl` - Extra large text
- `prose-slate` - Slate color scheme
- `prose-gray` - Gray color scheme
- `max-w-none` - Remove max-width constraint

---

## 🔨 Build Process

### Development

```bash
npm run dev
# Visit http://localhost:5173/about
```

Markdown pages work in dev mode with hot module replacement.

### Production Build

```bash
npm run build
```

**Expected Output**:
```
✓ built in 11.78s
> Using @sveltejs/adapter-static
  Wrote site to "build"
  ✔ done
```

**Generated Files**:
```
build/
├── about.html          # Static pre-rendered HTML
├── docs.html
├── privacy.html
├── terms.html
├── support.html
├── _app/              # SvelteKit app bundle
└── index.html
```

### Verify Static HTML

```bash
# Check that HTML was generated
ls -la build/*.html

# Verify SEO tags in HTML
grep "<title>" build/about.html
grep "description" build/about.html
```

---

## 🐛 Common Issues & Solutions

### Issue 1: Build Error - "Could not resolve ./src/lib/layouts/markdown.svelte"

**Error**:
```
Could not resolve "./src/lib/layouts/markdown.svelte" from "src/routes/about/+page.md"
```

**Solution**: Use absolute path with `resolve()`:

```javascript
// ❌ WRONG - relative path fails in build
layout: {
  markdown: './src/lib/layouts/markdown.svelte'
}

// ✅ CORRECT - absolute path with resolve()
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

layout: {
  markdown: resolve(__dirname, './src/lib/layouts/markdown.svelte')
}
```

---

### Issue 2: 404 Error During Prerender - "/favicon.png"

**Error**:
```
Error: 404 /favicon.png (linked from /about)
```

**Solution**: Add `handleHttpError` in svelte.config.js:

```javascript
kit: {
  adapter: adapter({...}),
  prerender: {
    handleHttpError: ({ path, referrer, message }) => {
      if (path === '/favicon.png') {
        return; // Ignore missing favicon
      }
      throw new Error(message);
    }
  }
}
```

---

### Issue 3: Markdown Not Styled Properly

**Symptoms**:
- Markdown renders as plain text
- No typography styling applied

**Solutions**:

1. **Verify Tailwind Typography is installed**:
```bash
npm list @tailwindcss/typography
```

2. **Check prose classes are applied**:
```svelte
<!-- Must wrap markdown content -->
<article class="prose prose-lg prose-slate max-w-none">
  <slot />
</article>
```

3. **Ensure Tailwind config includes typography plugin**:
```javascript
plugins: [
  require('@tailwindcss/typography'),
]
```

---

### Issue 4: Frontmatter Props Not Working

**Symptoms**:
- Title/description not showing in meta tags
- Layout component not receiving props

**Solution**: Use Svelte 4 export syntax in layout:

```svelte
<script lang="ts">
  // ✅ CORRECT - Svelte 4 style
  export let title = 'Default Title'
  export let description = 'Default description'
</script>

<svelte:head>
  <title>{title}</title>
  <meta name="description" content={description} />
</svelte:head>
```

---

### Issue 5: Pre-rendering Not Working

**Symptoms**:
- HTML files not generated in build output
- Pages still rendered client-side

**Solutions**:

1. **Verify `+page.ts` exists with prerender**:
```typescript
// src/routes/about/+page.ts
export const prerender = true
```

2. **Check adapter-static is configured**:
```javascript
import adapter from '@sveltejs/adapter-static';

kit: {
  adapter: adapter({
    pages: 'build',
    assets: 'build',
    fallback: 'index.html'
  })
}
```

3. **Ensure no dynamic parameters in route**:
- Routes with `[param]` cannot be pre-rendered without entries
- Use static routes only

---

## 📊 SEO Best Practices

### 1. Frontmatter Meta Tags

Always include in markdown frontmatter:

```yaml
---
title: Clear, Descriptive Page Title (50-60 chars)
description: Compelling meta description that includes keywords and call-to-action (150-160 chars)
layout: markdown
---
```

### 2. Semantic HTML

Use proper heading hierarchy:

```markdown
# Main Page Title (H1 - only one per page)

## Section Heading (H2)

### Subsection Heading (H3)

Regular paragraph text.
```

### 3. Internal Linking

Link to related pages:

```markdown
Learn more on our [Privacy Policy](/privacy) page.

For questions, visit our [Support](/support) section.
```

### 4. External Links

Open external links in new tab:

```markdown
Read the [HSE Guidelines](https://www.hse.gov.uk/guidance) for more information.
```

Or use HTML:

```html
<a href="https://www.hse.gov.uk" target="_blank" rel="noopener noreferrer">HSE Website</a>
```

---

## 🚀 Performance Optimization

### 1. Static Pre-rendering

- ✅ All static pages use `export const prerender = true`
- ✅ HTML generated at build time
- ✅ Fast initial page load
- ✅ No JavaScript required for content

### 2. Minimal JavaScript

- mdsvex pages are mostly HTML/CSS
- SvelteKit hydration only when needed
- Optimal for static content

### 3. Asset Optimization

```javascript
// In svelte.config.js
adapter: adapter({
  pages: 'build',
  assets: 'build',
  precompress: true,  // Enable gzip/brotli compression
  strict: true
})
```

---

## ✅ Testing Checklist

Before deploying markdown pages:

- [ ] All markdown files have proper frontmatter (title, description, layout)
- [ ] Each markdown page has a corresponding `+page.ts` with `prerender = true`
- [ ] `npm run build` completes without errors
- [ ] Static HTML files generated in `build/` directory
- [ ] Open generated HTML and verify:
  - [ ] `<title>` tag is correct
  - [ ] `<meta name="description">` is present
  - [ ] Markdown content is properly styled
  - [ ] Navigation links work
  - [ ] Footer is present
- [ ] Test pages in browser:
  - [ ] Dev mode: `npm run dev`
  - [ ] Preview mode: `npm run preview`
- [ ] Verify responsive design on mobile/tablet/desktop
- [ ] Check accessibility (headings, alt text, semantic HTML)

---

## 📚 References

### Official Documentation
- **mdsvex**: https://mdsvex.pngwn.io/
- **SvelteKit**: https://kit.svelte.dev/
- **Tailwind Typography**: https://tailwindcss.com/docs/typography-plugin
- **SvelteKit Prerendering**: https://kit.svelte.dev/docs/page-options#prerender

### Related Skills
- `.claude/skills/testing-frontend/SKILLS.md` - Frontend testing patterns
- `docs-dev/DEVELOPMENT_WORKFLOW.md` - Development workflow

### Example Implementation
- Session: `.claude/sessions/2025-11-19-public-routes-svelte-migration.md`
- Phase 7: Static page migration with mdsvex

---

## 🎓 Quick Start Template

Use this template for new markdown pages:

```bash
# 1. Create markdown file
# src/routes/my-page/+page.md

---
title: My Page Title
description: A clear, concise description of this page
layout: markdown
---

# My Page Title

Your markdown content here...

## Section Heading

More content...
```

```typescript
// 2. Create prerender config
// src/routes/my-page/+page.ts

export const prerender = true
```

```bash
# 3. Test in dev
npm run dev
# Visit http://localhost:5173/my-page

# 4. Build for production
npm run build

# 5. Verify HTML generated
ls -la build/my-page.html
grep "<title>" build/my-page.html
```

---

**Last Updated**: 2025-11-20
**Tested With**: SvelteKit 2.0, mdsvex 0.12.6, Svelte 4.2
