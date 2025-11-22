# Sync Performance Fix - Browser Freeze Issue

**Date**: 2025-11-22
**Issue**: Browser freezing when syncing Cases table with large datasets

## Root Cause Analysis

### The Problem
When the Cases table was repopulated with thousands of records, the progressive sync strategy caused the browser to freeze. Firefox showed "This page is slowing down Firefox" warning.

### Why Cases Froze But Notices Didn't

**Cases Sync Strategy (Problematic)**:
- Synced 3 years of cases (~thousands of records)
- Processed each message individually: `processCaseMessage()` called for EVERY record
- Each call triggered:
  1. IndexedDB insert
  2. Svelte store update (`addCase()`)
  3. UI reactivity/invalidation
- **Result**: Main thread blocked processing thousands of synchronous operations

**Notices Sync Strategy (Worked Fine)**:
- Also synced 40K records initially
- BUT: Client-side slicing to 100 records (`slice(0, 100)`)
- Only 100 records visible to user
- Less pressure on UI rendering

## The Fix: Batching + Progressive Rendering

### Changes to `sync-cases.ts`

1. **Message Batching**:
   - Buffer incoming messages instead of processing one-by-one
   - Process in batches of 100 messages
   - Debounce with 50ms delay for small batches

2. **Chunked Processing**:
   - Break large batches into chunks of 50 records
   - Process each chunk separately

3. **requestIdleCallback**:
   - Yield to browser between chunks
   - Prevents main thread blocking
   - Browser can handle user input, rendering, etc.
   - Fallback to `setTimeout(fn, 0)` for older browsers

### Code Changes

```typescript
// Before (processed one at a time)
async function processCaseMessage(msg: any, phase: string) {
  // Immediate IndexedDB insert + store update
  casesCollection.insert(data)
  addCase(data)
}

// After (batched with idle callbacks)
async function processCaseMessage(msg: any, phase: string) {
  // Add to buffer
  messageBatches[phase].push(msg)

  // Process after 50ms OR when 100 messages accumulated
  if (batch.length >= 100) {
    await processBatchedMessages(phase)
  }
}

async function processBatchedMessages(phase: string) {
  // Process in chunks of 50
  for (let i = 0; i < messages.length; i += CHUNK_SIZE) {
    // Use requestIdleCallback to yield between chunks
    await new Promise((resolve) => {
      requestIdleCallback(() => {
        // Process chunk
        resolve()
      }, { timeout: 100 })
    })
  }
}
```

## Performance Benefits

1. **Reduced function call overhead**: 1 batch call instead of 1000 individual calls
2. **Reduced store updates**: Batch updates instead of per-record reactivity
3. **Non-blocking**: Browser remains responsive during sync
4. **Better progress tracking**: Batch-level logging shows clearer progress

## Testing

To test the fix:

1. **Clear browser data** (IndexedDB) for clean start
2. **Hard refresh** (Ctrl+Shift+R) to reload ElectricSQL shapes
3. **Monitor browser console** for batch processing logs:
   ```
   [Cases Sync] Processed recent batch: 100 inserts, 0 updates, 0 deletes
   ```
4. **Check browser responsiveness** - should NOT show "slowing down" warning
5. **Monitor system resources** using `./scripts/monitor-memory.sh`

## Future Optimizations

If performance is still an issue with very large datasets:

1. **Virtual Scrolling**: Only render visible table rows (react-window, tanstack-virtual)
2. **Pagination**: Limit visible records (already at 20 per page)
3. **Web Workers**: Move sync processing to background thread
4. **IndexedDB Transactions**: Batch inserts into single transaction
5. **Reduce store reactivity**: Update stores less frequently during sync

## Related Files

- `frontend/src/lib/electric/sync-cases.ts` - Fixed batching implementation
- `frontend/src/lib/electric/sync-notices.ts` - Working reference implementation
- `scripts/monitor-memory.sh` - Memory monitoring tool
- `MEMORY-MONITORING.md` - General memory debugging guide

## Lessons Learned

1. **ElectricSQL sync can overwhelm browser** with large datasets if not handled carefully
2. **Message-by-message processing doesn't scale** past ~100 records
3. **requestIdleCallback is essential** for non-blocking sync
4. **Batching is critical** for performance
5. **Progressive strategies vary by data volume**:
   - Small datasets (<1K): Direct sync fine
   - Medium datasets (1K-10K): Batching required
   - Large datasets (>10K): Batching + chunking + idle callbacks required
