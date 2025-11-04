// ~/.config/finicky/finicky.ts
//
// Finicky configuration file.
// - Sets Google Chrome as the default browser.
// - Routes Google Meet links specifically to the "Secture" Chrome profile.
// - Opens Zoom links directly in the Zoom app.

import type { FinickyConfig } from "/Applications/Finicky.app/Contents/Resources/finicky.d.ts";

export default {
    defaultBrowser: "Google Chrome",
    options: {
        hideIcon: true
    },
    handlers: [
        {
            match: finicky.matchHostnames(["meet.google.com"]),
            browser: { name: "Google Chrome", profile: "Secture" }
        },
        {
            // @ts-expect-error - Finicky types are outdated, this syntax works correctly
            match: ({ url }) => url.host.includes("zoom.us"),
            browser: "us.zoom.xos"
        }
    ]
} satisfies FinickyConfig;
