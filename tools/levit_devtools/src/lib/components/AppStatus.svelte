<script lang="ts">
    import { Indicator, Button } from "flowbite-svelte";
    import { connectionState, registryState } from "$lib/stores";

    function selectApp(id: string) {
        registryState.selectedAppId = id;
    }
</script>

<div class="flex items-center gap-3">
    {#if registryState.apps.length === 0}
        <div class="flex items-center gap-2 px-3 py-1 bg-gray-800 rounded-lg">
            <span class="text-gray-400 text-sm"
                >⏳ Waiting for app connection...</span
            >
        </div>
    {:else}
        {#each registryState.apps as app}
            <button
                type="button"
                class="flex items-center gap-2 px-3 py-1.5 rounded-lg transition-colors border text-sm font-medium
                {registryState.selectedAppId === app.id
                    ? 'bg-blue-600 text-white border-blue-500 shadow-md'
                    : 'bg-gray-800 text-gray-300 border-gray-700 hover:bg-gray-700 hover:text-white'}"
                onclick={() => selectApp(app.id)}
            >
                <span class="text-xs">{registryState.selectedAppId === app.id ? '●' : '○'}</span>
                {app.name}
            </button>
        {/each}
    {/if}

    <div class="flex items-center gap-2 ml-2 pl-2 border-l border-gray-700">
        <Indicator
            color={connectionState.status === "connected"
                ? "green"
                : connectionState.status === "connecting"
                  ? "yellow"
                  : "red"}
            class={connectionState.status === "connecting"
                ? "animate-pulse"
                : ""}
        />
        <span class="text-gray-400 text-xs capitalize"
            >{connectionState.status}</span
        >
    </div>
</div>
