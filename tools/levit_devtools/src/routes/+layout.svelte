<script lang="ts">
  import '../app.css';

  let { children } = $props();
</script>

<svelte:head>
  <title>LevitDevTools</title>
  <meta name="description" content="Developer tools for Levit framework" />
</svelte:head>

<div class="min-h-screen bg-gray-900">
  {@render children()}
</div>
