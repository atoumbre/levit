<script lang="ts">
    import type { RegistryItem, ReactiveItem } from "$lib/types";
    import { reactiveState } from "$lib/stores";
    import { Badge } from "flowbite-svelte";
    import VariableInspector from "./VariableInspector.svelte";

    let { item }: { item: RegistryItem | null } = $props();
    let selectedStateId = $state<string | null>(null);

    // Get linked state for this controller
    const linkedState = $derived.by(() => {
        if (!item) return [];

        const linked: ReactiveItem[] = [];
        // Registry item's scopeId is a number (0 for root, 1+ for scoped)
        const registryScopeId = String(item.scopeId);

        reactiveState.state.forEach((stateItem) => {
            const controller = stateItem.ownerId || stateItem.flags?.controller;
            const itemScopeId = stateItem.scopeId || stateItem.flags?.scopeId;

            if (controller === item.key) {
                if (item.scopeId > 0) {
                    // Scoped: exact match on scopeId (both as strings)
                    if (String(itemScopeId) === registryScopeId) {
                        linked.push(stateItem);
                    }
                } else {
                    // Global scope (scopeId === 0): match items with null/0/undefined scopeId
                    if (!itemScopeId || String(itemScopeId) === "0") {
                        linked.push(stateItem);
                    }
                }
            }
        });

        return linked;
    });

    const selectedState = $derived(
        selectedStateId
            ? linkedState.find((s) => s.id === selectedStateId)
            : linkedState[0],
    );

    function selectState(id: string) {
        selectedStateId = id;
    }

    function getUpdateCount(id: string): number {
        return reactiveState.updateCounts.get(id) || 0;
    }
</script>

{#if !item}
    <div class="flex items-center justify-center h-full text-gray-500">
        <div class="text-center">
            <span class="text-3xl">🎯</span>
            <p class="mt-2">Select a controller to inspect</p>
        </div>
    </div>
{:else}
    <div class="h-full flex flex-col space-y-4 overflow-hidden">
        <!-- Controller Header -->
        <div
            class="flex items-center gap-2 px-3 py-2 bg-gray-800 rounded-lg flex-wrap shrink-0"
        >
            <span class="text-lg">
                {item.isFactory ? "🏭" : item.isAsync ? "⏳" : "📦"}
            </span>
            <span class="font-semibold text-gray-200"
                >{item.type || item.key}</span
            >
            <span class="text-gray-500 text-sm font-mono">
                {item.scope || "root"}#{item.scopeId}
            </span>
            <div class="flex gap-1 ml-auto">
                {#if item.isLazy}<Badge color="yellow">lazy</Badge>{/if}
                {#if item.isFactory}<Badge color="blue">factory</Badge>{/if}
                {#if item.isAsync}<Badge color="cyan">async</Badge>{/if}
                {#if item.permanent}<Badge color="green">perm</Badge>{/if}
            </div>
        </div>

        <!-- State Variables Section -->
        <div
            class="flex-1 min-h-0 bg-gray-800/50 rounded-lg border border-purple-500/20 overflow-hidden flex flex-col"
        >
            <div
                class="flex items-center justify-between px-3 py-2 bg-gray-800 border-b border-gray-700 shrink-0"
            >
                <h4 class="text-sm font-medium text-gray-300">
                    ⚡ Reactive State
                </h4>
                <Badge color="purple">{linkedState.length}</Badge>
            </div>

            {#if linkedState.length === 0}
                <p class="p-4 text-gray-500 text-center text-sm">
                    No reactive variables registered for this controller
                </p>
            {:else}
                <div class="flex-1 grid grid-cols-[200px_1fr] min-h-0">
                    <!-- Variable List -->
                    <div
                        class="border-r border-gray-700 h-full overflow-y-auto"
                    >
                        {#each linkedState as stateItem}
                            {@const updateCount = getUpdateCount(stateItem.id)}
                            <button
                                type="button"
                                class="w-full flex items-center gap-1 px-2 py-1.5 text-left text-sm border-b border-gray-700
                  hover:bg-gray-700/50 transition-colors
                  {selectedState?.id === stateItem.id
                                    ? 'bg-purple-900/30 border-l-2 border-purple-500'
                                    : ''}"
                                onclick={() => selectState(stateItem.id)}
                            >
                                <span class="text-purple-400">⚡</span>
                                <span class="text-gray-200 truncate flex-1">
                                    {stateItem.name ||
                                        stateItem.flags?.name ||
                                        "<unnamed>"}
                                </span>
                                {#if updateCount > 1}
                                    <Badge color="purple" class="text-xs"
                                        >{updateCount}×</Badge
                                    >
                                {/if}
                            </button>
                        {/each}
                    </div>

                    <!-- Shared Variable Inspector -->
                    <div class="p-3 h-full overflow-y-auto bg-gray-900/50">
                        <VariableInspector variable={selectedState || null} />
                    </div>
                </div>
            {/if}
        </div>
    </div>
{/if}
