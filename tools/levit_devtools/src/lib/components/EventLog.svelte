<script lang="ts">
    import { eventsState, clearEvents } from "$lib/stores";
    import { Badge, Button } from "flowbite-svelte";

    function formatTime(timestamp: string): string {
        return new Date(timestamp).toLocaleTimeString();
    }

    function getCategoryColor(category: string): "blue" | "purple" | "gray" {
        if (category === "di") return "blue";
        if (category === "state") return "purple";
        return "gray";
    }

    function getEventIcon(type: string): string {
        switch (type) {
            case "di_register":
                return "📦";
            case "di_resolve":
                return "🔗";
            case "di_delete":
                return "🗑️";
            case "di_instance_create":
                return "🏗️";
            case "di_instance_init":
                return "✅";
            case "reactive_init":
                return "⚡";
            case "state_change":
                return "🔄";
            case "reactive_dispose":
                return "❌";
            case "batch":
                return "📦";
            case "graph_change":
                return "🕸️";
            default:
                return "📋";
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
                            color={getCategoryColor(event.category as string)}
                            class="shrink-0"
                        >
                            {(event.category as string) || 'evt'}
                        </Badge>
                        <span class="text-lg shrink-0">
                            {getEventIcon(event.type)}
                        </span>
                        <span class="text-gray-300 text-sm truncate font-mono">
                            {event.type.replace('reactive_', '').replace('di_', '')}
                        </span>
                        
                        {#if event.key}
                            <span class="text-gray-400 text-sm truncate font-medium">
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

                        {#if event.type === 'batch'}
                            <Badge color="purple" size="xs">
                                {event.count} updates
                            </Badge>
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

                        {#if event.scopeName}
                            <span
                                class="text-gray-500 text-xs font-mono ml-auto shrink-0"
                            >
                                {event.scopeName}#{event.scopeId}
                            </span>
                        {:else if event.scopeId !== undefined}
                            <span
                                class="text-gray-500 text-xs font-mono ml-auto shrink-0"
                            >
                                scope#{event.scopeId}
                            </span>
                        {/if}
                    </div>
                {/each}
            </div>
        {/if}
    </div>
</div>
