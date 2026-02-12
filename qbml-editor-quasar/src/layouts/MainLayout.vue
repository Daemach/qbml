<template>
  <q-layout view="hHh lpR fFf">
    <q-header elevated class="bg-dark">
      <q-toolbar>
        <q-avatar square size="32px" class="q-mr-sm">
          <img src="~assets/qbml-icon.svg" alt="QBML" />
        </q-avatar>

        <q-toolbar-title>
          QBML Editor
        </q-toolbar-title>

        <q-btn
          flat
          dense
          :icon="$q.dark.isActive ? 'light_mode' : 'dark_mode'"
          :title="$q.dark.isActive ? 'Switch to light mode' : 'Switch to dark mode'"
          @click="$q.dark.toggle()"
        />

        <q-btn
          flat
          dense
          icon="help_outline"
          title="qb Documentation"
          href="https://qb.ortusbooks.com/"
          target="_blank"
        />

        <q-btn
          flat
          dense
          icon="code"
          title="GitHub"
          href="https://github.com/Daemach/qbml"
          target="_blank"
        />
      </q-toolbar>
    </q-header>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup>
//
</script>

<style>
html, body, #q-app {
  height: 100%;
  overflow: hidden;
}
</style>
