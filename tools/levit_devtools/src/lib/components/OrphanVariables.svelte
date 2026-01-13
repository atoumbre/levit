<script lang="ts">
    import type { ReactiveItem } from "$lib/types";
    import { reactiveState } from "$lib/stores";
    import { Badge } from "flowbite-svelte";
    import VariableInspector from "./VariableInspector.svelte";

    let selectedId = $state<string | null>(null);

    // Get orphan variables (no controller assigned)
    const orphanVariables = $derived.by(() => {
        const orphans: ReactiveItem[] = [];

        reactiveState.state.forEach((item) => {
            const controller = item.ownerId || item.flags?.controller;
            // Orphan = no controller or empty controller
            if (!controller || controller === "") {
                orphans.push(item);
            }
        });

        return orphans;
    });

    const selectedVariable = $derived(
        selectedId
            ? orphanVariables.find((v) => v.id === selectedId)
            : orphanVariables[0],
    );

    function selectVariable(id: string) {
        selectedId = id;
    }

    function getUpdateCount(id: string): number {
        return reactiveState.updateCounts.get(id) || 0;
    }
</script>

<div class="h-full flex flex-col">
    {#if orphanVariables.length === 0}
        <div class="flex-1 flex items-center justify-center text-gray-500">
            <div class="text-center">
                <span class="text-4xl">🎉</span>
                <p class="mt-2">No orphan variables</p>
                <p class="text-sm text-gray-600 mt-1">
                    All reactive state is properly associated with controllers
                </p>
            </div>
        </div>
    {:else}
        <div class="grid grid-cols-[250px_1fr] h-full">
            <!-- Variable List -->
            <div class="border-r border-gray-700 overflow-y-auto">
                <div
                    class="px-3 py-2 bg-gray-800 border-b border-gray-700 flex items-center justify-between"
                >
                    <h3 class="text-sm font-medium text-gray-300">
                        ⚠️ Orphan Variables
                    </h3>
                    <Badge color="yellow">{orphanVariables.length}</Badge>
                </div>

                <div class="divide-y divide-gray-800">
                    {#each orphanVariables as variable}
                        {@const updateCount = getUpdateCount(variable.id)}
                        <button
                            type="button"
                            class="w-full flex items-center gap-2 px-3 py-2 text-left hover:bg-gray-800/50 transition-colors
                {selectedVariable?.id === variable.id
                                ? 'bg-yellow-900/20 border-l-2 border-yellow-500'
                                : ''}"
                            onclick={() => selectVariable(variable.id)}
                        >
                            <span class="text-yellow-400">⚡</span>
                            <div class="flex-1 min-w-0">
                                <div class="text-gray-200 truncate text-sm">
                                    {variable.name ||
                                        variable.flags?.name ||
                                        "<unnamed>"}
                                </div>
                                <div
                                    class="text-gray-500 text-xs font-mono truncate"
                                >
                                    {variable.valueType || "dynamic"}
                                </div>
                            </div>
                            {#if updateCount > 1}
                                <Badge color="yellow" class="shrink-0"
                                    >{updateCount}×</Badge
                                >
                            {/if}
                        </button>
                    {/each}
                </div>
            </div>

            <!-- Shared Variable Inspector -->
            <div class="overflow-y-auto p-4">
                <VariableInspector variable={selectedVariable || null} />
            </div>
        </div>
    {/if}
</div>
