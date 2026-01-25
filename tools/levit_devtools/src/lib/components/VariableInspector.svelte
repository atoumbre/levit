<script lang="ts">
    import type { ReactiveItem } from "$lib/types";
    import { reactiveState } from "$lib/stores";
    import { Badge, Card } from "flowbite-svelte";
    import JsonViewer from "./JsonViewer.svelte";

    let { variable }: { variable: ReactiveItem | null } = $props();

    const history = $derived(
        variable ? reactiveState.history.get(variable.id) || [] : [],
    );

    function getUpdateCount(id: string): number {
        return reactiveState.updateCounts.get(id) || 0;
    }
</script>

{#if !variable}
    <div class="flex items-center justify-center h-full text-gray-500">
        <p>Select a variable to inspect</p>
    </div>
{:else}
    <div class="space-y-4">
        <!-- Header Card -->
        <Card class="max-w-none" padding="md">
            <div class="flex items-center gap-3">
                <span class="text-2xl">⚡</span>
                <div>
                    <h3 class="text-lg font-semibold text-gray-200">
                        {variable.name || variable.flags?.name || "<unnamed>"}
                    </h3>
                    <span class="text-gray-500 text-sm font-mono"
                        >{variable.valueType || "dynamic"}</span
                    >
                </div>
            </div>

            <div class="grid grid-cols-3 gap-4 mt-4">
                <div class="bg-gray-900 rounded p-2">
                    <span class="text-xs text-gray-500 block">Scope ID</span>
                    <span class="text-gray-300 font-mono text-sm"
                        >{variable.scopeId ||
                            variable.flags?.scopeId ||
                            "N/A"}</span
                    >
                </div>
                <div class="bg-gray-900 rounded p-2">
                    <span class="text-xs text-gray-500 block">Controller</span>
                    <span class="text-gray-300 font-mono text-sm truncate block"
                        >{variable.ownerId ||
                            variable.flags?.controller ||
                            "None"}</span
                    >
                </div>
                <div class="bg-gray-900 rounded p-2">
                    <span class="text-xs text-gray-500 block">Updates</span>
                    <span class="text-gray-300 font-mono text-sm"
                        >{getUpdateCount(variable.id)}</span
                    >
                </div>
            </div>
        </Card>

        <!-- Current Value -->
        <Card class="max-w-none" padding="none">
            <div class="px-4 py-2 border-b border-gray-700">
                <h4 class="text-sm font-medium text-gray-300">Current Value</h4>
            </div>
            <div class="p-4 bg-gray-900">
                <JsonViewer value={variable.newValue} />
            </div>
        </Card>

        <!-- History -->
        {#if history.length > 0}
            <Card class="max-w-none" padding="none">
                <div
                    class="px-4 py-2 border-b border-gray-700 flex items-center justify-between"
                >
                    <h4 class="text-sm font-medium text-gray-300">History</h4>
                    <Badge color="gray">{history.length}</Badge>
                </div>
                <div
                    class="divide-y divide-gray-700 max-h-[200px] overflow-y-auto"
                >
                    {#each history.slice(0, 20) as h}
                        {@const eventType =
                            (h as any).event || (h as any).type || "unknown"}
                        <div class="px-4 py-2 flex items-center gap-3">
                            <span
                                class="text-gray-500 text-xs font-mono w-20 shrink-0"
                            >
                                {new Date(
                                    h.timestamp || "",
                                ).toLocaleTimeString()}
                            </span>

                            <!-- Event Type -->
                            <Badge
                                color={eventType === "reactive_init"
                                    ? "blue"
                                    : eventType === "register" ||
                                        eventType === "di_register"
                                      ? "indigo"
                                      : eventType === "state_change" ||
                                          eventType === "update"
                                        ? "purple"
                                        : "gray"}
                                class="w-20 justify-center shrink-0"
                            >
                                {eventType
                                    .replace("reactive_", "")
                                    .replace("di_", "")}
                            </Badge>

                            <span
                                class="text-red-400 text-sm truncate max-w-[100px]"
                            >
                                {JSON.stringify(h.oldValue)}
                            </span>
                            <span class="text-gray-600">→</span>
                            <span
                                class="text-green-400 text-sm truncate max-w-[100px]"
                            >
                                {JSON.stringify(h.newValue)}
                            </span>
                        </div>
                    {/each}
                </div>
            </Card>
        {/if}
    </div>
{/if}
