# Guarana

A tiny macOS menu bar app for toggling `caffeinate -d`.

Click the guarana icon to keep it awake.

Right-click or Control-click the menu bar icon for uptime, `Keep Display On`, `Turn On` / `Turn Off`, and `Quit`.

`Keep Display On` is enabled by default. When disabled, Guarana still keeps the Mac awake from idle sleep, but it does not pass `-d` to force the display to stay on.

## Build

Requirements:

- macOS
- Xcode command line tools

```sh
make
```

The app bundle is created at:

```text
build/Guarana.app
```

Run it with:

```sh
make run
```

To install it for regular use, copy the built app into `/Applications`:

```sh
cp -R build/Guarana.app /Applications/
```

## Process Cleanup

When enabled, the app runs:

```sh
/usr/bin/caffeinate -d -w <app-pid>
```

If `Keep Display On` is unchecked, it runs:

```sh
/usr/bin/caffeinate -w <app-pid>
```

The `-w` option makes `caffeinate` release its assertion and exit when the app process exits. The app also terminates its child process when toggled off, when quitting normally, and when receiving `SIGINT`, `SIGTERM`, or `SIGHUP`.

## Why Guarana?

I like the drink Guaraná Antarctica. The guarana berry is native to the Amazon basin and contains caffeine, keeping you (and the Mac) awake. The app's icon is a stylized guarana berry from [Lívia Zambolim](https://www.behance.net/gallery/108504977/Redesign-de-logo-Guarana-Antarctica?tracking_source=search_projects_recommended%7Cguarana).