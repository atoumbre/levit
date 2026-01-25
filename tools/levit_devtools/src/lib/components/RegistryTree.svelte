<script lang="ts">
    import type { RegistryItem, ReactiveItem } from "$lib/types";
    import { registryState, reactiveState } from "$lib/stores";
    import { Badge } from "flowbite-svelte";

    interface ScopeNode {
        id: string;
        name: string;
        parentId: number | null;
        items: RegistryItem[];
        children: ScopeNode[];
    }

    let { onSelect }: { onSelect?: (item: RegistryItem) => void } = $props();
    let selectedKey = $state<string | null>(null);

    // Build scope tree from reactive registry
    const scopeTree = $derived.by(() => {
        const items = Array.from(registryState.registry.values());
        console.log(
            `[RegistryTree] Processing ${items.length} items. Selected App: ${registryState.selectedAppId}`,
        );

        if (items.length === 0) return [];

        const scopeMap = new Map<string, ScopeNode>();
        let matchedCount = 0;

        items.forEach((item) => {
            // Filter by selected app
            if (
                registryState.selectedAppId &&
                item.appId &&
                item.appId !== registryState.selectedAppId
            ) {
                return;
            }
            matchedCount++;

            const scopeId = String(item.scopeId ?? "0");
            const scopeName = item.scope || "root";
            const parentId = item.parentScopeId ?? null;

            if (!scopeMap.has(scopeId)) {
                scopeMap.set(scopeId, {
                    id: scopeId,
                    name: scopeName,
                    parentId: parentId,
                    items: [],
                    children: [],
                });
            }
            scopeMap.get(scopeId)!.items.push(item);
        });

        console.log(
            `[RegistryTree] Matched ${matchedCount} items in ${scopeMap.size} scopes`,
        );

        // Build parent-child relationships
        scopeMap.forEach((scope) => {
            if (scope.parentId !== null && scope.parentId !== undefined) {
                const parentIdStr = String(scope.parentId);
                if (parentIdStr !== scope.id) {
                    const parent = scopeMap.get(parentIdStr);
                    if (parent) {
                        parent.children.push(scope);
                    }
                }
            }
        });

        // Get root scopes
        const roots = Array.from(scopeMap.values()).filter(
            (s) =>
                s.parentId === null ||
                s.parentId === undefined ||
                !scopeMap.has(String(s.parentId)) ||
                String(s.parentId) === s.id,
        );

        roots.sort((a, b) => {
            if (a.name === "root") return -1;
            if (b.name === "root") return 1;
            return Number(a.id) - Number(b.id);
        });

        console.log(`[RegistryTree] Final tree has ${roots.length} root nodes`);
        return roots;
    });

    // Fallback: All matched items as a flat list if tree building results in 0 roots
    const flatItems = $derived.by(() => {
        if (scopeTree.length > 0) return [];
        return Array.from(registryState.registry.values()).filter((item) => {
            if (
                registryState.selectedAppId &&
                item.appId &&
                item.appId !== registryState.selectedAppId
            )
                return false;
            return true;
        });
    });

    function selectItem(item: RegistryItem) {
        selectedKey =
            item.fullKey || `${item.appId}:${item.scopeId}:${item.key}`;
        onSelect?.(item);
    }

    function getStateCount(item: RegistryItem): number {
        const registryScopeId = String(item.scopeId);
        let count = 0;

        reactiveState.state.forEach((stateItem: ReactiveItem) => {
            // Must match the application ID
            if (stateItem.appId !== item.appId) return;

            const controller = stateItem.ownerId || stateItem.flags?.controller;
            const itemScopeId = stateItem.scopeId || stateItem.flags?.scopeId;

            // Strict match on key (the registry item's unique key is the controller name/type)
            if (controller === item.key) {
                if (Number(item.scopeId) > 0) {
                    // Scoped: exact match on scopeId
                    if (String(itemScopeId) === registryScopeId) count++;
                } else {
                    // Global scope (scopeId === 0): match items with null/0/undefined scopeId
                    if (!itemScopeId || String(itemScopeId) === "0") count++;
                }
            }
        });

        return count;
    }
</script>

<div class="space-y-1">
    <!-- Quick Debug Stats -->
    <div
        class="px-2 py-1 text-[10px] font-mono text-gray-500 bg-gray-900/30 rounded border border-gray-800"
    >
        Registry: {registryState.registry.size} | Apps: {registryState.apps
            .length} | Selected: {registryState.selectedAppId || "none"} | Roots:
        {scopeTree.length} | Matched: {scopeTree.reduce(
            (acc, s) => acc + s.items.length,
            0,
        )}
    </div>

    {#if scopeTree.length > 0}
        {#each scopeTree as scope}
            {@render scopeNode(scope, 0)}
        {/each}
    {:else if flatItems.length > 0}
        <div class="p-2 text-xs text-yellow-500 bg-yellow-900/10 rounded">
            ⚠️ Showing flat list (tree building failed)
        </div>
        {#each flatItems as item}
            {@render registryItemNode(item)}
        {/each}
    {/if}
</div>

{#snippet registryItemNode(item: RegistryItem)}
    {@const stateCount = getStateCount(item)}
    {@const itemKey =
        item.fullKey || `${item.appId}:${item.scopeId}:${item.key}`}
    <button
        type="button"
        class="w-full flex items-center gap-2 px-2 py-1 text-left hover:bg-gray-800 rounded transition-colors
{selectedKey === itemKey ? 'bg-blue-900/30 border-l-2 border-blue-500' : ''}"
        onclick={() => selectItem(item)}
    >
        <span>{item.isFactory ? "🏭" : item.isAsync ? "⏳" : "📦"}</span>
        <span class="text-gray-200 truncate">{item.type || item.key}</span>
        {#if stateCount > 0}
            <Badge color="purple" class="ml-1">⚡{stateCount}</Badge>
        {/if}
        <div class="flex gap-1 ml-auto">
            {#if item.isLazy}<Badge color="yellow">lazy</Badge>{/if}
            {#if item.isFactory}<Badge color="blue">factory</Badge>{/if}
            {#if item.isAsync}<Badge color="cyan">async</Badge>{/if}
            {#if item.permanent}<Badge color="green">perm</Badge>{/if}
        </div>
    </button>
{/snippet}

{#snippet scopeNode(scope: ScopeNode, depth: number)}
    <div style="margin-left: {depth * 1}rem">
        <!-- Scope Header -->
        <div
            class="flex items-center gap-2 px-2 py-1 text-gray-400 text-sm hover:bg-gray-800 rounded cursor-pointer"
        >
            <span class="text-gray-500"
                >{scope.children.length > 0 || scope.items.length > 0
                    ? "▼"
                    : "•"}</span
            >
            <span
                >{scope.name === "root"
                    ? "🌳"
                    : scope.children.length > 0
                      ? "📂"
                      : "📁"}</span
            >
            <span class="font-medium text-gray-300">{scope.name}</span>
            <span class="text-gray-600 text-xs">#{scope.id}</span>
            <Badge color="gray" class="ml-auto">{scope.items.length}</Badge>
        </div>

        <!-- Items -->
        <div class="ml-4 space-y-0.5">
            {#each scope.items as item}
                {@const stateCount = getStateCount(item)}
                {@const itemKey =
                    item.fullKey || `${item.appId}:${item.scopeId}:${item.key}`}
                <button
                    type="button"
                    class="w-full flex items-center gap-2 px-2 py-1 text-left hover:bg-gray-800 rounded transition-colors
            {selectedKey === itemKey
                        ? 'bg-blue-900/30 border-l-2 border-blue-500'
                        : ''}"
                    onclick={() => selectItem(item)}
                >
                    <span
                        >{item.isFactory
                            ? "🏭"
                            : item.isAsync
                              ? "⏳"
                              : "📦"}</span
                    >
                    <span class="text-gray-200 truncate"
                        >{item.type || item.key}</span
                    >
                    {#if stateCount > 0}
                        <Badge color="purple" class="ml-1">⚡{stateCount}</Badge
                        >
                    {/if}
                    <div class="flex gap-1 ml-auto">
                        {#if item.isLazy}<Badge color="yellow">lazy</Badge>{/if}
                        {#if item.isFactory}<Badge color="blue">factory</Badge
                            >{/if}
                        {#if item.isAsync}<Badge color="cyan">async</Badge>{/if}
                        {#if item.permanent}<Badge color="green">perm</Badge
                            >{/if}
                    </div>
                </button>
            {/each}

            <!-- Children -->
            {#each scope.children.sort((a, b) => Number(a.id) - Number(b.id)) as child}
                {@render scopeNode(child, depth + 1)}
            {/each}
        </div>
    </div>
{/snippet}
