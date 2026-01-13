<script lang="ts">
    import { JsonView } from "@zerodevx/svelte-json-view";

    let { value }: { value: unknown } = $props();
</script>

<JsonView json={value} />
