<script lang="ts">
    import { onMount } from "svelte";
    import { Navbar, NavBrand, Tabs, TabItem } from "flowbite-svelte";
    import type { RegistryItem } from "$lib/types";
    import { connect } from "$lib/stores";
    import {
        AppStatus,
        RegistryTree,
        StateInspector,
        EventLog,
        OrphanVariables,
        DependencyGraph,
    } from "$lib/components";

    let selectedItem = $state<RegistryItem | null>(null);

    onMount(() => {
        connect();
    });

    function handleSelect(item: RegistryItem) {
        selectedItem = item;
    }
</script>

<div class="flex flex-col h-screen">
    <!-- Header -->
    <Navbar class="border-b border-gray-700">
        <NavBrand>
            <span
                class="text-lg font-semibold bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent"
            >
                🧲 LevitDevTools
            </span>
        </NavBrand>
        <AppStatus />
    </Navbar>

    <!-- Main Content -->
    <main class="flex-1 overflow-hidden">
        <Tabs tabStyle="underline" contentClass="p-0 bg-gray-900">
            <TabItem title="📦 Registry" open>
                <div class="grid grid-cols-[350px_1fr] h-[calc(100vh-100px)]">
                    <!-- Tree Panel -->
                    <div class="border-r border-gray-700 overflow-y-auto p-2">
                        <RegistryTree onSelect={handleSelect} />
                    </div>

                    <!-- Detail Panel -->
                    <div class="flex flex-col p-4 h-full">
                        <StateInspector item={selectedItem} />
                    </div>
                </div>
            </TabItem>

            <TabItem title="⚠️ Orphans">
                <div class="h-[calc(100vh-100px)]">
                    <OrphanVariables />
                </div>
            </TabItem>

            <TabItem title="📜 Events">
                <div class="h-[calc(100vh-100px)]">
                    <EventLog />
                </div>
            </TabItem>

            <TabItem title="🔗 Graph">
                <div class="h-[calc(100vh-100px)] p-4">
                    <DependencyGraph />
                </div>
            </TabItem>
        </Tabs>
    </main>
</div>
