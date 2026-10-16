#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build"
stage="$out/stage"
rm -rf "$stage"
mkdir -p "$stage"
cp -r "$root/ReplicatedStorage/ImGui" "$stage/ImGui"
cp "$root/LICENSE" "$stage/ImGui/LICENSE.txt"
cp "$root/StarterPlayerScripts/ImGuiDemo.local.luau" "$stage/ImGuiDemo.client.luau"
cat > "$stage/ImGui.project.json" <<'JSON'
{ "name": "ImGui", "tree": { "$path": "ImGui" } }
JSON
cat > "$stage/ImGuiDemo.project.json" <<'JSON'
{ "name": "ImGuiDemo", "tree": { "$path": "ImGuiDemo.client.luau" } }
JSON
rojo build "$stage/ImGui.project.json" -o "$out/ImGui.rbxm"
rojo build "$stage/ImGuiDemo.project.json" -o "$out/ImGuiDemo.rbxm"
rm -rf "$stage"
echo "built $out/ImGui.rbxm $out/ImGuiDemo.rbxm"
