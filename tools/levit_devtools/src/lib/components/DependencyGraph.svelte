<script lang="ts">
    import { graphState, getControllerGroups } from "$lib/stores/graph.svelte";
    import { onMount, onDestroy } from "svelte";
    import * as d3Force from "d3-force";
    import * as d3Zoom from "d3-zoom";
    import * as d3Drag from "d3-drag";
    import * as d3Selection from "d3-selection";

    interface SimNode extends d3Force.SimulationNodeDatum {
        id: string;
        name: string;
        type: string;
        isComputed: boolean;
        controllerId: string;
        controllerScope: string;
        groupId: string;
        groupIndex: number;
    }

    interface SimLink extends d3Force.SimulationLinkDatum<SimNode> {
        source: string | SimNode;
        target: string | SimNode;
    }

    // State
    let selectedNode = $state<string | null>(null);
    let controllerFilter = $state("all");

    // DOM Elements
    let svgElement = $state<SVGSVGElement | null>(null);
    let zoomGroupElement = $state<SVGGElement | null>(null);
    let svgContainer = $state<HTMLDivElement | null>(null);

    // Simulation State
    let simNodes = $state<SimNode[]>([]);
    let simLinks = $state<SimLink[]>([]);

    let simulation: d3Force.Simulation<SimNode, SimLink> | null = null;
    let zoomBehavior: d3Zoom.ZoomBehavior<SVGSVGElement, unknown> | null = null;
    let resizeObserver: ResizeObserver | null = null;

    let lastEdgeCount = 0;

    // Draggable controller groups
    let groupPositions = $state(new Map<string, { x: number; y: number }>());
    let draggingGroupId = $state<string | null>(null); // For styling only
    let currentTransform = { k: 1, x: 0, y: 0 };

    let controllerGroupsList = $derived(getControllerGroups());

    const groupColors = [
        "#6366f1",
        "#10b981",
        "#f59e0b",
        "#ef4444",
        "#8b5cf6",
        "#ec4899",
        "#06b6d4",
        "#84cc16",
        "#f97316",
        "#14b8a6",
    ];

    function getGroupColor(index: number): string {
        return groupColors[index % groupColors.length];
    }

    let groupedNodes = $derived.by(() => {
        const groups = new Map<string, SimNode[]>();
        simNodes.forEach((node) => {
            const gid = node.groupId || "unknown";
            if (!groups.has(gid)) groups.set(gid, []);
            groups.get(gid)!.push(node);
        });
        return groups;
    });

    let connectedIds = $derived.by(() => {
        if (!selectedNode) return new Set<string>();
        const connected = new Set<string>([selectedNode]);
        graphState.edges.forEach((e) => {
            if (e.source === selectedNode) connected.add(e.target);
            if (e.target === selectedNode) connected.add(e.source);
        });
        return connected;
    });

    function getNode(id: string): SimNode | undefined {
        return simNodes.find((n) => n.id === id);
    }

    function initGroupLayout(groupIds: string[]) {
        if (
            groupPositions.size > 0 &&
            Array.from(groupPositions.keys()).every((k) => groupIds.includes(k))
        ) {
            return;
        }
        const newMap = new Map<string, { x: number; y: number }>();
        const cols = Math.ceil(Math.sqrt(groupIds.length));

        const spacingX = 500;
        const spacingY = 450;

        const totalWidth = cols * spacingX;
        const totalHeight = Math.ceil(groupIds.length / cols) * spacingY;
        const startX = -totalWidth / 2;
        const startY = -totalHeight / 2;

        groupIds.forEach((id, i) => {
            if (groupPositions.has(id)) {
                newMap.set(id, groupPositions.get(id)!);
            } else {
                newMap.set(id, {
                    x: startX + (i % cols) * spacingX,
                    y: startY + Math.floor(i / cols) * spacingY,
                });
            }
        });
        groupPositions = newMap;
    }

    function buildSimulation() {
        if (graphState.edges.length === 0) return;

        const groups = getControllerGroups();
        const layoutGroups = groups
            .filter((g) => g.id !== "all")
            .map((g) => g.id);

        initGroupLayout(layoutGroups);
        const groupIndexMap = new Map(layoutGroups.map((id, i) => [id, i]));

        const nodeIds = new Set<string>();
        graphState.edges.forEach((e) => {
            nodeIds.add(e.source);
            nodeIds.add(e.target);
        });

        const nodes: SimNode[] = Array.from(nodeIds).map((id, i) => {
            const controllerId =
                graphState.nodeControllers.get(id) || "unknown";
            const scopeId = graphState.nodeScopes.get(id) || "global";
            const groupId =
                controllerId !== "unknown"
                    ? `${controllerId}::${scopeId}`
                    : "unknown";
            const existingNode = simNodes.find((n) => n.id === id);
            const groupPos = groupPositions.get(groupId) || { x: 0, y: 0 };

            return {
                id,
                name: graphState.nodeNames.get(id) || id,
                type: graphState.nodeTypes.get(id) || "unknown",
                isComputed: graphState.computedIds.has(id),
                controllerId,
                controllerScope: scopeId,
                groupId,
                groupIndex: groupIndexMap.get(groupId) ?? 0,
                x: existingNode?.x ?? groupPos.x + (Math.random() - 0.5) * 100,
                y: existingNode?.y ?? groupPos.y + (Math.random() - 0.5) * 100,
                vx: existingNode?.vx ?? 0,
                vy: existingNode?.vy ?? 0,
            };
        });

        const links: SimLink[] = graphState.edges.map((e) => ({
            source: e.source,
            target: e.target,
        }));

        if (simulation) {
            simulation.stop();
        }

        simulation = d3Force
            .forceSimulation(nodes)
            .force(
                "link",
                d3Force
                    .forceLink<SimNode, SimLink>(links)
                    .id((d) => d.id)
                    .distance(80)
                    .strength(0.1),
            )
            .force("charge", d3Force.forceManyBody().strength(-200))
            .force("collision", d3Force.forceCollide().radius(40))
            .force(
                "x",
                d3Force
                    .forceX<SimNode>()
                    .x((d) => groupPositions.get(d.groupId)?.x ?? 0)
                    .strength(0.25),
            )
            .force(
                "y",
                d3Force
                    .forceY<SimNode>()
                    .y((d) => groupPositions.get(d.groupId)?.y ?? 0)
                    .strength(0.25),
            )
            .alphaDecay(0.02);

        simulation.on("tick", () => {
            simNodes = nodes.map((n) => ({ ...n }));
            simLinks = links.map((l) => ({ ...l }));
        });

        if (nodes.length > 0 && lastEdgeCount === 0) {
            setTimeout(zoomToFit, 500);
        }
    }

    // --- Actions ---

    function draggable(node: SVGGElement, groupId: string) {
        let startPos = { x: 0, y: 0 };

        const drag = d3Drag
            .drag<SVGGElement, unknown>()
            .subject(() => {
                const pos = groupPositions.get(groupId) || { x: 0, y: 0 };
                return { x: pos.x, y: pos.y };
            })
            .on("start", (event) => {
                // Prevent zoom
                event.sourceEvent.stopPropagation();

                draggingGroupId = groupId;
                simulation?.alphaTarget(0.3).restart();
            })
            .on("drag", (event) => {
                const newMap = new Map(groupPositions);
                // event.x/y are already transformed by d3-drag using the subject
                newMap.set(groupId, { x: event.x, y: event.y });
                groupPositions = newMap;

                // Update forces
                simulation?.force(
                    "x",
                    d3Force
                        .forceX<SimNode>()
                        .x((d) => groupPositions.get(d.groupId)?.x ?? 0)
                        .strength(0.4),
                ); // slightly stronger pull during drag
                simulation?.force(
                    "y",
                    d3Force
                        .forceY<SimNode>()
                        .y((d) => groupPositions.get(d.groupId)?.y ?? 0)
                        .strength(0.4),
                );
            })
            .on("end", () => {
                draggingGroupId = null;
                simulation?.alphaTarget(0);
            });

        d3Selection.select(node).call(drag);

        return {
            destroy() {
                d3Selection.select(node).on(".drag", null);
            },
        };
    }

    // --- Interaction Logic ---

    $effect(() => {
        if (svgElement && zoomGroupElement && !zoomBehavior) {
            initZoom(svgElement, zoomGroupElement);
        }
    });

    function initZoom(svg: SVGSVGElement, g: SVGGElement) {
        const svgSel = d3Selection.select(svg);
        const gSel = d3Selection.select(g);

        zoomBehavior = d3Zoom
            .zoom<SVGSVGElement, unknown>()
            .scaleExtent([0.01, 8])
            .on("zoom", (event) => {
                gSel.attr("transform", event.transform);
                currentTransform = event.transform;
            });

        svgSel.call(zoomBehavior).on("dblclick.zoom", () => zoomToFit()); // Double click background to fit
    }

    // --- Zoom Controls ---

    function zoomIn() {
        if (!svgElement || !zoomBehavior) return;
        d3Selection
            .select(svgElement)
            .transition()
            .duration(300)
            .call(zoomBehavior.scaleBy, 1.4);
    }

    function zoomOut() {
        if (!svgElement || !zoomBehavior) return;
        d3Selection
            .select(svgElement)
            .transition()
            .duration(300)
            .call(zoomBehavior.scaleBy, 0.6);
    }

    function resetView() {
        if (!svgElement || !zoomBehavior) return;
        d3Selection
            .select(svgElement)
            .transition()
            .duration(500)
            .call(zoomBehavior.transform, d3Zoom.zoomIdentity);
    }

    function zoomToFit() {
        if (
            !svgElement ||
            !svgContainer ||
            !zoomBehavior ||
            filteredNodes.length === 0
        )
            return;

        let minX = Infinity,
            maxX = -Infinity,
            minY = Infinity,
            maxY = -Infinity;
        filteredNodes.forEach((node) => {
            if (node.x === undefined || node.y === undefined) return;
            if (node.x < minX) minX = node.x;
            if (node.x > maxX) maxX = node.x;
            if (node.y < minY) minY = node.y;
            if (node.y > maxY) maxY = node.y;
        });

        minX -= 100;
        maxX += 100;
        minY -= 100;
        maxY += 100;

        if (minX === Infinity) return;

        const width = maxX - minX;
        const height = maxY - minY;
        const cx = minX + width / 2;
        const cy = minY + height / 2;

        const containerWidth = svgContainer.clientWidth;
        const containerHeight = svgContainer.clientHeight;

        if (
            width <= 0 ||
            height <= 0 ||
            containerWidth <= 0 ||
            containerHeight <= 0
        )
            return;

        const scale =
            0.9 / Math.max(width / containerWidth, height / containerHeight);
        const finalScale = Math.min(2, Math.max(0.01, scale));

        const transform = d3Zoom.zoomIdentity
            .translate(containerWidth / 2, containerHeight / 2)
            .scale(finalScale)
            .translate(-cx, -cy);

        d3Selection
            .select(svgElement)
            .transition()
            .duration(750)
            .call(zoomBehavior.transform, transform);
    }

    $effect(() => {
        if (!svgElement) {
            zoomBehavior = null;
        }
    });

    function checkForChanges() {
        if (
            graphState.edges.length !== lastEdgeCount &&
            graphState.edges.length > 0
        ) {
            lastEdgeCount = graphState.edges.length;
            buildSimulation();
        }
    }

    onMount(() => {
        buildSimulation();
        resizeObserver = new ResizeObserver(() => {
            /* Layout stable */
        });
        if (svgContainer) resizeObserver.observe(svgContainer);

        const interval = setInterval(checkForChanges, 1000);
        return () => {
            clearInterval(interval);
            resizeObserver?.disconnect();
        };
    });

    // --- Filtering ---
    let filteredNodes = $derived(
        controllerFilter === "all"
            ? simNodes
            : simNodes.filter((n) => n.groupId === controllerFilter),
    );

    let filteredLinks = $derived(
        controllerFilter === "all"
            ? simLinks
            : simLinks.filter((l) => {
                  const sourceId =
                      typeof l.source === "string" ? l.source : l.source.id;
                  const targetId =
                      typeof l.target === "string" ? l.target : l.target.id;
                  const sourceNode = simNodes.find((n) => n.id === sourceId);
                  const targetNode = simNodes.find((n) => n.id === targetId);
                  return (
                      sourceNode?.groupId === controllerFilter ||
                      targetNode?.groupId === controllerFilter
                  );
              }),
    );

    function handleNodeClick(nodeId: string, event: MouseEvent) {
        event.stopPropagation();
        selectedNode = selectedNode === nodeId ? null : nodeId;
    }

    function getNodeOpacity(nodeId: string): number {
        if (!selectedNode) return 1;
        return connectedIds.has(nodeId) ? 1 : 0.15;
    }

    function getLinkOpacity(source: string, target: string): number {
        if (!selectedNode) return 0.5;
        return source === selectedNode || target === selectedNode ? 1 : 0.08;
    }

    function getFriendlyGroupName(groupId: string): string {
        const parts = groupId.split("::");
        const name = parts[0];
        const scope = parts[1];
        if (scope && scope !== "global") {
            return `${name} (${scope.slice(0, 6)})`;
        }
        return name;
    }

    function reheatSimulation() {
        if (simulation) {
            simNodes.forEach((n) => {
                const pos = groupPositions.get(n.groupId);
                if (pos) {
                    n.x = pos.x + (Math.random() - 0.5) * 50;
                    n.y = pos.y + (Math.random() - 0.5) * 50;
                }
            });
            simulation.nodes(simNodes);
            simulation.alpha(1).restart();
        } else {
            buildSimulation();
        }
    }
</script>

<div class="h-full bg-gray-800 rounded-lg p-4 flex flex-col">
    <!-- Header -->
    <div class="flex items-center justify-between mb-3 flex-wrap gap-2">
        <h3 class="text-sm font-semibold text-gray-400">🔗 Dependency Graph</h3>

        <div class="flex items-center gap-2">
            <select
                bind:value={controllerFilter}
                class="bg-gray-700 text-gray-300 text-xs rounded px-2 py-1 border-none max-w-[200px]"
            >
                {#each controllerGroupsList as group}
                    <option value={group.id}>
                        {group.id === "all"
                            ? "🏠 All Controllers"
                            : `📦 ${group.name}${group.scope && group.scope !== "global" ? ` (${group.scope.slice(0, 6)})` : ""}`}
                    </option>
                {/each}
            </select>

            <!-- Zoom Controls -->
            <div class="flex items-center gap-1 bg-gray-700 rounded px-2 py-1">
                <button
                    type="button"
                    onclick={zoomOut}
                    class="text-gray-400 hover:text-white px-1 font-mono font-bold"
                    title="Zoom Out">−</button
                >
                <button
                    type="button"
                    onclick={zoomIn}
                    class="text-gray-400 hover:text-white px-1 font-mono font-bold"
                    title="Zoom In">+</button
                >
                <div class="w-[1px] h-3 bg-gray-600 mx-1"></div>
                <button
                    type="button"
                    onclick={zoomToFit}
                    class="text-gray-400 hover:text-white px-1 text-xs"
                    title="Fit to Screen">Fit</button
                >
                <button
                    type="button"
                    onclick={resetView}
                    class="text-gray-400 hover:text-white px-1 text-xs"
                    title="Reset View">1:1</button
                >
            </div>

            <button
                type="button"
                onclick={reheatSimulation}
                class="bg-gray-700 hover:bg-gray-600 text-gray-400 hover:text-white px-2 py-1 rounded text-xs"
                title="Re-run force simulation"
            >
                🔄 Layout
            </button>
        </div>

        <div class="flex items-center gap-3 text-xs text-gray-500">
            <span class="flex items-center gap-1">
                <span class="w-3 h-3 rounded-full bg-indigo-500"></span>
                Computed ({filteredNodes.filter((n) => n.isComputed).length})
            </span>
            <span class="flex items-center gap-1">
                <span class="w-3 h-3 rounded-full bg-emerald-500"></span>
                Reactive ({filteredNodes.filter((n) => !n.isComputed).length})
            </span>
        </div>
    </div>

    <!-- Node info -->
    <div
        class="bg-gray-700 rounded px-3 py-2 mb-3 text-sm min-h-[40px] flex items-center justify-between"
    >
        {#if selectedNode}
            {@const node = getNode(selectedNode)}
            {#if node}
                <div>
                    <span
                        class={node.isComputed
                            ? "text-indigo-300"
                            : "text-emerald-300"}
                    >
                        {node.isComputed ? "⚡" : "📦"}
                    </span>
                    <span class="text-gray-200 font-medium ml-1"
                        >{node.name}</span
                    >
                    <span class="text-gray-400 ml-2">: {node.type}</span>
                    <span class="text-gray-500 ml-2 text-xs">
                        @ {node.controllerId}
                        {#if node.controllerScope && node.controllerScope !== "global"}
                            <span class="text-gray-600 ml-1"
                                >({node.controllerScope.slice(0, 6)})</span
                            >
                        {/if}
                    </span>
                </div>
                <button
                    type="button"
                    onclick={() => (selectedNode = null)}
                    class="text-gray-500 hover:text-white">✕</button
                >
            {/if}
        {:else}
            <span class="text-gray-500 italic"
                >Double-click background to fit • Scroll to zoom • Drag
                background to pan</span
            >
        {/if}
    </div>

    <!-- Graph -->
    <div
        bind:this={svgContainer}
        class="flex-1 overflow-hidden rounded-lg bg-gray-900 border border-gray-700 relative"
    >
        {#if filteredNodes.length === 0}
            <div
                class="flex flex-col items-center justify-center h-full text-gray-500"
            >
                <p class="text-sm">No dependencies yet</p>
            </div>
        {:else}
            <svg
                bind:this={svgElement}
                width="100%"
                height="100%"
                class="w-full h-full block cursor-grab active:cursor-grabbing touch-none"
                role="application"
                aria-label="Dependency Graph"
            >
                <defs>
                    <marker
                        id="arrow"
                        markerWidth="10"
                        markerHeight="7"
                        refX="32"
                        refY="3.5"
                        orient="auto"
                    >
                        <polygon points="0 0, 10 3.5, 0 7" fill="#818cf8" />
                    </marker>
                </defs>

                <!-- Zoom Group (Transform applied directly by D3) -->
                <g bind:this={zoomGroupElement}>
                    <!-- Group backgrounds (Draggable) -->
                    {#each Array.from(groupedNodes.entries()) as [groupId, groupNodes]}
                        {#if (controllerFilter === "all" || controllerFilter === groupId) && groupNodes.length > 0}
                            {@const groupIndex = groupNodes[0].groupIndex}
                            {@const xs = groupNodes.map((n) => n.x ?? 0)}
                            {@const ys = groupNodes.map((n) => n.y ?? 0)}
                            {@const minX = Math.min(...xs) - 50}
                            {@const maxX = Math.max(...xs) + 50}
                            {@const minY = Math.min(...ys) - 50}
                            {@const maxY = Math.max(...ys) + 50}
                            <!-- svelte-ignore a11y_no_static_element_interactions -->
                            <g
                                use:draggable={groupId}
                                class="cursor-move hover:opacity-100 transition-opacity"
                                opacity={draggingGroupId &&
                                draggingGroupId !== groupId
                                    ? 0.3
                                    : 1}
                            >
                                <rect
                                    x={minX}
                                    y={minY - 20}
                                    width={maxX - minX}
                                    height={maxY - minY + 20}
                                    rx="12"
                                    fill={getGroupColor(groupIndex)}
                                    fill-opacity="0.08"
                                    stroke={getGroupColor(groupIndex)}
                                    stroke-opacity="0.3"
                                    stroke-width="2"
                                />
                                <text
                                    x={minX + 8}
                                    y={minY - 4}
                                    fill={getGroupColor(groupIndex)}
                                    font-size="12"
                                    font-weight="bold"
                                    opacity="0.9"
                                >
                                    {getFriendlyGroupName(groupId)}
                                </text>
                                <title
                                    >Drag {getFriendlyGroupName(groupId)}</title
                                >
                            </g>
                        {/if}
                    {/each}

                    <!-- Links -->
                    {#each filteredLinks as link}
                        {@const src =
                            typeof link.source === "string"
                                ? getNode(link.source)
                                : link.source}
                        {@const tgt =
                            typeof link.target === "string"
                                ? getNode(link.target)
                                : link.target}
                        {#if src?.x !== undefined && tgt?.x !== undefined}
                            <line
                                x1={src.x}
                                y1={src.y}
                                x2={tgt.x}
                                y2={tgt.y}
                                stroke="#818cf8"
                                stroke-width="2"
                                stroke-opacity={getLinkOpacity(src.id, tgt.id)}
                                marker-end="url(#arrow)"
                                pointer-events="none"
                            />
                        {/if}
                    {/each}

                    <!-- Nodes -->
                    {#each filteredNodes as node}
                        {#if node.x !== undefined}
                            <!-- svelte-ignore a11y_click_events_have_key_events -->
                            <!-- svelte-ignore a11y_no_static_element_interactions -->
                            <g
                                transform="translate({node.x}, {node.y})"
                                class="cursor-pointer"
                                style="opacity: {getNodeOpacity(node.id)}"
                                onclick={(e) => handleNodeClick(node.id, e)}
                            >
                                {#if selectedNode === node.id}
                                    <circle
                                        r="36"
                                        fill="none"
                                        stroke="#f59e0b"
                                        stroke-width="3"
                                    />
                                {/if}
                                <circle
                                    r="28"
                                    fill={node.isComputed
                                        ? "#312e81"
                                        : "#064e3b"}
                                    stroke={node.isComputed
                                        ? "#6366f1"
                                        : "#10b981"}
                                    stroke-width="2"
                                />
                                <text
                                    text-anchor="middle"
                                    dy="4"
                                    fill="white"
                                    font-size="11"
                                    font-weight="500"
                                    style="pointer-events:none"
                                >
                                    {node.name.length > 10
                                        ? node.name.slice(0, 10) + "…"
                                        : node.name}
                                </text>
                                <text
                                    text-anchor="middle"
                                    dy="42"
                                    fill="#9ca3af"
                                    font-size="9"
                                    style="pointer-events:none"
                                >
                                    {node.type.length > 14
                                        ? node.type.slice(0, 14) + "…"
                                        : node.type}
                                </text>
                            </g>
                        {/if}
                    {/each}
                </g>
                <!-- End Zoom Group -->
            </svg>
        {/if}
    </div>

    <p class="text-xs text-gray-600 mt-2 text-center">
        Scroll to zoom • Drag background to pan • Drag colored boxes to move
        groups
    </p>
</div>
