// Preferences for the game's dedicated Firefox profile. The start scripts copy this file
// into the profile on every launch. Firefox has no app mode, so these settings (with
// userChrome.css) make the window look and behave like one.

// No welcome, onboarding, privacy-notice or "what's new" tabs.
user_pref("browser.aboutwelcome.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.uitour.enabled", false);

// The stop scripts close the game from outside; never offer to restore a session.
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.warnOnQuit", false);

// Hide the browser chrome: native title bar (keeps window controls), no tabs, toolbars or sidebar.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("sidebar.revamp", false);
user_pref("sidebar.verticalTabs", false);
