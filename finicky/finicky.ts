// ~/.config/finicky/finicky.ts
//
// Finicky configuration file.
// - Sets Google Chrome as the default browser.
// - Routes Google Meet links specifically to the "Secture" Chrome profile.

import type { FinickyConfig } from "/Applications/Finicky.app/Contents/Resources/finicky.d.ts";

export default {
    defaultBrowser: "Google Chrome",
    handlers: [
        {
            match: finicky.matchHostnames(["meet.google.com"]),
            browser: { name: "Google Chrome", profile: "Secture" }
        }
    ]
} satisfies FinickyConfig;
