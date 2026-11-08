# AnimalSurvivalFinal — Developer README

<!-- Project Stack -->
![Roblox](https://img.shields.io/badge/Platform-Roblox-e30000?logo=roblox&logoColor=white)
![Rojo](https://img.shields.io/badge/Sync-Rojo-00b300?logo=roblox&logoColor=white)
![Wally](https://img.shields.io/badge/Packages-Wally-5c6bc0?logoColor=white)
![Rokit](https://img.shields.io/badge/Toolchain-Rokit-f57c00?logoColor=white)

<!-- Contribution Policy -->
![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen?logo=github&logoColor=white)

---

> **Maintained by:** InsightiveHQ Technical Production  
> **Architecture:** Multi-place (Lobby + Main Game)  
> **Toolchain:** Rokit · Rojo · Wally · Git

---

## ⚠️ Ground Rules

| Rule | Detail |
|------|--------|
| **Never push to `main`** | All work goes on a feature/bugfix branch |
| **One branch per task** | Keep history clean and PRs reviewable |
| **Always pull before branching** | Prevents merge conflicts downstream |

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Toolchain Setup (Rokit, Rojo, Wally)](#2-toolchain-setup)
3. [Clone the Repository](#3-clone-the-repository)
4. [Daily Workflow](#4-daily-workflow)
5. [Branch Management](#5-branch-management)
6. [Pushing & Pull Requests](#6-pushing--pull-requests)
7. [Resolving Merge Conflicts](#7-resolving-merge-conflicts)
8. [Rojo Server Configuration](#8-rojo-server-configuration)

---

## 1. Prerequisites

Ensure Git is installed and your GitHub credentials or SSH key are configured before proceeding.

```bash
git --version
```

---

## 2. Toolchain Setup

This project uses **Rokit** to pin exact versions of Rojo, Wally, StyLua and Selene across the team (see `rokit.toml`). Run these once after cloning.

### 2.1 Install Tools via Rokit

Installs every tool pinned in `rokit.toml` (`rokit add <tool>` is only for adding a new tool to the project):

```bash
rokit install
```

### 2.2 Install Package Dependencies via Wally

Downloads all external libraries defined in `wally.toml` into `Packages/`, which both Rojo projects sync to `ReplicatedStorage.Packages`:

```bash
wally install
```

> `wally package` is for publishing a package to the Wally registry. It is not part of setup.

### 2.3 Lint and Format

```bash
selene src
stylua src
```

---

## 3. Clone the Repository

**HTTPS:**

```bash
git clone https://github.com/InsightiveHQ/AnimalSurvivalFinal.git
cd AnimalSurvivalFinal
```

**SSH (preferred):**

```bash
git clone git@github.com:InsightiveHQ/AnimalSurvivalFinal.git
cd AnimalSurvivalFinal
```

---

## 4. Daily Workflow

Follow this order every session — no exceptions:

```
1. git checkout main
2. git pull origin main
3. git checkout -b feature/your-feature-name
4. [ make changes ]
5. git add .
6. git commit -m "Short, clear description"
7. git push -u origin feature/your-feature-name
8. Open a Pull Request on GitHub
```

---

## 5. Branch Management

### Create a Branch

```bash
git checkout -b feature/your-feature-name
```

Use clear, descriptive names:

| Type | Example |
|------|---------|
| New feature | `feature/hunger-system` |
| Bug fix | `fix/spawn-position-bug` |
| Asset update | `asset/new-animal-models` |

### Verify Current Branch

```bash
git branch
```

### Check Modified Files

```bash
git status
```

### Stage & Commit

```bash
git add .
git commit -m "Add hunger depletion and feeding mechanic"
```

---

## 6. Pushing & Pull Requests

### First Push (new branch)

```bash
git push -u origin feature/your-feature-name
```

### Subsequent Pushes

```bash
git push
```

### Opening a PR

1. Go to [https://github.com/InsightiveHQ/AnimalSurvivalFinal](https://github.com/InsightiveHQ/AnimalSurvivalFinal)
2. Click **Compare & pull request** next to your branch
3. Write a clear description of what changed and why
4. Request a reviewer before merging

> PRs without descriptions will be sent back.

---

## 7. Resolving Merge Conflicts

Conflicts occur when two contributors edited the same lines. Here's how to resolve them cleanly.

### Step 1 — Identify Conflicted Files

```bash
git status
```

### Step 2 — Open and Edit the Conflict

Conflicted files contain markers like this:

```
<<<<<<< HEAD
Your local change
=======
Incoming change from remote
>>>>>>> main
```

Delete the markers. Keep the correct code (yours, theirs, or a merge of both).

### Step 3 — Stage the Resolved File

```bash
git add <resolved-file-path>
```

### Step 4 — Complete the Merge

```bash
git commit -m "Resolve merge conflict in <file>"
```

### Step 5 — Push

```bash
git push
```

> If you're unsure which version to keep, **ask before merging** — don't guess and overwrite someone else's work.

---

## 8. Rojo Server Configuration

This repo splits the game into two places. Each place has its own Rojo project file and port.

| Place | Command | Port |
|-------|---------|------|
| Main Game | `rojo serve main.project.json` | `8000` |
| Lobby | `rojo serve lobby.project.json` | `8001` |

### Start the Correct Server

**Main Game only:**

```bash
rojo serve main.project.json
```

**Lobby only:**

```bash
rojo serve lobby.project.json
```

**Both simultaneously** — open two terminal tabs and run both commands side by side.

### Connect in Roblox Studio

1. Open the target place file in Studio
2. Go to **Plugins → Rojo** to open the plugin widget
3. Set the port to match your running server:
   - Main Game → `http://localhost:8000`
   - Lobby → `http://localhost:8001`
4. Click **Connect**

> **Plugin won't connect?** Confirm your terminal is actively running the server and that the port in Studio matches exactly.

---

## Quick Reference

```bash
# Full new-session flow
git checkout main
git pull origin main
git checkout -b feature/my-feature
# ... make changes ...
git add .
git commit -m "Describe what you did"
git push -u origin feature/my-feature
# → Open PR on GitHub
```

---

*For toolchain version changes, update `rokit.toml` and notify the team before merging.*
