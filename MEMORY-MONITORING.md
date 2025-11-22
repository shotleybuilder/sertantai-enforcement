# Memory Leak Debugging Guide

## Quick Check Commands

### 1. Check Current Memory Status
```bash
# System memory
free -h

# Phoenix app processes
ps aux | grep "beam.smp" | grep "mix phx.server" | grep -v grep

# Detailed view with memory
ps aux | grep "beam.smp" | grep "mix phx.server" | grep -v grep | awk '{printf "PID %s: MEM=%s%% RSS=%sMB VSZ=%sMB\n", $2, $4, int($6/1024), int($5/1024)}'
```

### 2. Monitor Over Time
```bash
# Run in background, creates memory-monitor.csv
./scripts/monitor-memory.sh 10 600   # Check every 10s for 10 minutes
```

### 3. Watch Top Memory Consumers
```bash
# Real-time monitoring
htop -p $(pgrep -d',' -f "mix phx.server")
```

## What to Look For

### Signs of Memory Leak:
1. **RSS steadily increasing** over time (not just spikes)
2. **Atom count approaching limit** (check in IEx)
3. **Process count growing** without bound

### Normal Behavior:
- VSZ is high (3-4GB) but stable - this is NORMAL
- RSS fluctuates but returns to baseline - this is NORMAL
- CPU spikes during requests - this is NORMAL

## Checking Atom Table (Most Common Elixir Leak)

If you can open an IEx console when freezing occurs:

```elixir
# Check atom usage
atom_count = :erlang.system_info(:atom_count)
atom_limit = :erlang.system_info(:atom_limit)
IO.puts("Atoms: #{atom_count} / #{atom_limit} (#{Float.round(atom_count/atom_limit*100, 1)}%)")

# If > 80%, you have an atom leak!
```

## Common Causes in Our App

1. **RunPod API responses** - if we're converting response keys to atoms
2. **Dynamic module creation** - if AI responses trigger code generation
3. **GenServer registration** - if registering with dynamic names
4. **ETS tables** - if creating tables with dynamic names

## Current Baseline (2025-11-22)

**System**: 27% memory used (4.3GB / 15.7GB)
**Auth App (9013)**: 116MB RSS - Normal
**EHS App (9151)**: 168MB RSS - Normal

If RSS for either app exceeds **500MB**, investigate immediately.
If atom % exceeds **50%**, investigate immediately.
