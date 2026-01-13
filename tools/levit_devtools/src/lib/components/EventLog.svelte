<script lang="ts">
    import { eventsState, clearEvents } from "$lib/stores";
    import { Badge, Button } from "flowbite-svelte";

    function formatTime(timestamp: string): string {
        return new Date(timestamp).toLocaleTimeString();
    }

    function getCategoryColor(category: string): "blue" | "purple" {
        return category === "di" ? "blue" : "purple";
    }

    function getEventIcon(category: string, event: string): string {
        if (category === "di") {
            switch (event) {
                case "register":
                    return "📦";
                case "resolve":
                    return "🔗";
                case "delete":
                    return "🗑️";
                default:
                    return "📋";
            }
        } else {
            switch (event) {
                case "init":
                    return "⚡";
                case "update":
                    return "🔄";
                case "dispose":
                    return "❌";
                default:
                    return "📊";
            }
        }
    }
</script>

<div class="h-full flex flex-col">
    <!-- Header -->
    <div
        class="flex items-center justify-between px-3 py-2 bg-gray-800 border-b border-gray-700"
    >
        <h3 class="text-sm font-medium text-gray-300">📜 Event Log</h3>
        <div class="flex items-center gap-2">
            <Badge color="gray">{eventsState.events.length}</Badge>
            <Button size="xs" color="red" outline onclick={clearEvents}
                >Clear</Button
            >
        </div>
    </div>

    <!-- Event List -->
    <div class="flex-1 overflow-y-auto">
        {#if eventsState.events.length === 0}
            <div class="flex items-center justify-center h-full text-gray-500">
                <p>No events yet</p>
            </div>
        {:else}
            <div class="divide-y divide-gray-800">
                {#each eventsState.events as event}
                    <div
                        class="flex items-center gap-2 px-3 py-2 hover:bg-gray-800/50 transition-colors"
                    >
                        <span
                            class="text-gray-500 text-xs font-mono w-20 shrink-0"
                        >
                            {formatTime(event.timestamp)}
                        </span>
                        <Badge
                            color={getCategoryColor(event.category)}
                            class="shrink-0"
                        >
                            {event.category}
                        </Badge>
                        <span class="text-lg shrink-0">
                            {getEventIcon(event.category, event.event)}
                        </span>
                        <span class="text-gray-300 text-sm truncate">
                            {event.event}
                        </span>
                        {#if event.key}
                            <span class="text-gray-400 text-sm truncate">
                                {event.key}
                            </span>
                        {/if}
                        {#if event.name}
                            <span
                                class="text-indigo-400 text-sm font-medium truncate"
                            >
                                {event.name}
                            </span>
                        {/if}
                        {#if event.ownerId}
                            <Badge color="indigo" size="xs" class="font-mono">
                                owner:{event.ownerId}
                            </Badge>
                        {/if}
                        {#if event.newValue !== undefined}
                            <div
                                class="flex items-center gap-1 text-xs font-mono"
                            >
                                {#if event.oldValue !== undefined}
                                    <span class="text-gray-500"
                                        >{JSON.stringify(event.oldValue)}</span
                                    >
                                    <span class="text-gray-400">→</span>
                                {/if}
                                <span
                                    class="text-green-400 max-w-[150px] truncate"
                                    title={JSON.stringify(event.newValue)}
                                >
                                    {JSON.stringify(event.newValue)}
                                </span>
                            </div>
                        {/if}
                        {#if event.scope}
                            <span
                                class="text-gray-500 text-xs font-mono ml-auto shrink-0"
                            >
                                {event.scope}#{event.scopeId}
                            </span>
                        {/if}
                    </div>
                {/each}
            </div>
        {/if}
    </div>
</div>
