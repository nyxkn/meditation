# Ignore warnings about missing ShortcutBadger class
-dontwarn me.leolin.shortcutbadger.**

# Prevent optimization or obfuscation of BadgeManager methods that reference ShortcutBadger
# do we need this? it builds fine without as well
-keep class me.carda.awesome_notifications.core.managers.BadgeManager {
    public *;
}
