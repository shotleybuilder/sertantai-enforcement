# NCDB2Phx Package Integration Errors

**Date:** 2025-08-05  
**Session:** sync-manager-12  
**Package Version:** GitHub - shotleybuilder/ncdb_2_phx  

## Issue Summary

The `ncdb_2_phx` package was successfully fetched from GitHub via `mix deps.get`, but compilation fails due to several issues in the package code.

## Compilation Error

**Primary Error:**
```
error: undefined variable "index"
│
 91 │             source_record_id: "csv_row_#{index}",
│                                          ^^^^^
│
└─ lib/ncdb_2_phx/utilities/source_adapter.ex:91:42: AirtableSyncPhoenix.Utilities.SourceAdapter (module)
```

**Location:** `lib/ncdb_2_phx/utilities/source_adapter.ex:91`  
**Module:** `AirtableSyncPhoenix.Utilities.SourceAdapter`  

## Additional Warnings

The package also has numerous warnings that should be addressed:

### Deprecated Logger Usage
- Multiple `Logger.warn/1` calls should be updated to `Logger.warning/2`
- Affects multiple files in the package

### Unused Variables
- Multiple unused variables that should be prefixed with underscore
- Pattern: `variable "name" is unused (if the variable is not meant to be used, prefix it with an underscore)`

### Module Naming Issues
- Package still contains references to `AirtableSyncPhoenix` instead of `NCDB2Phx`
- This suggests incomplete module renaming during package extraction

## Integration Status

- ✅ **Package Fetch:** Successfully downloaded from GitHub
- ✅ **Dependency Resolution:** No dependency conflicts
- ❌ **Compilation:** Fails due to undefined variable error
- ❌ **Integration Testing:** Cannot proceed due to compilation failure

## Files That Work with NCDB2Phx (EHS Project Side)

From review of `lib/ehs_enforcement/sync/`:

### ✅ **Working Files:**
- `lib/ehs_enforcement/sync/generic.ex` - Compatibility wrapper, delegates to NCDB2Phx
- `lib/ehs_enforcement/sync/adapters/airtable_adapter.ex` - Implements NCDB2Phx.Utilities.SourceAdapter behaviour

### 📁 **Generic Package Integration:**
- `lib/ehs_enforcement/sync/generic/` - Contains old extracted package files (should be removed)
- Legacy modules that have been moved to the package

### 🔄 **Other Sync Files:**
Most other files in `lib/ehs_enforcement/sync/` appear to be EHS-specific and don't directly integrate with ncdb_2_phx:
- `enhanced_sync.ex`, `sync_manager.ex`, `sync_worker.ex` - EHS-specific sync orchestration
- `error_*.ex`, `integrity_*.ex` - EHS-specific error handling and validation
- `resources/` - EHS-specific Ash resources

## Next Steps (For Future Session)

1. **Fix Package Compilation Error:**
   - Address undefined `index` variable in source_adapter.ex
   - Complete module renaming from AirtableSyncPhoenix to NCDB2Phx
   - Fix deprecated Logger.warn calls

2. **Clean Up EHS Project:**
   - Remove old `lib/ehs_enforcement/sync/generic/` directory after package is working
   - Verify all module references point to package correctly

3. **Test Integration:**
   - Compile successfully
   - Test basic sync functionality
   - Verify Airtable adapter works with package

## Files Working Together

**Package Side (ncdb_2_phx):**
- Core sync engine and utilities
- Generic resource definitions
- LiveView components for sync UI

**EHS Project Side:**
- `EhsEnforcement.Sync.Generic` - Compatibility wrapper
- `EhsEnforcement.Sync.Adapters.AirtableAdapter` - Airtable-specific adapter
- EHS-specific sync orchestration and management