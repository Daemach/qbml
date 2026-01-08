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
          icon="help_outline"
          title="QBML Documentation"
          href="https://qb.ortusbooks.com/"
          target="_blank"
        />

        <q-btn
          flat
          dense
          icon="code"
          title="GitHub"
          href="https://github.com/coldbox-modules/qb"
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
}
</style>
