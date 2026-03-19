<template>
  <div class="badge">{{ message }}</div>
</template>

<script setup lang="ts">
const message = "ok";
fetch("/api/healthz");
</script>
