//––– Helper struct for “entertainment” –––
const Entertainment = struct {
    movies: []const u8 = "",
    books: []const []const u8 = &.{}, // JSON array of strings
    games: []const []const u8 = &.{},
    tv_shows: []const []const u8 = &.{},
};

//––– Preferences, now with “trackingPreferences” and “subscriptions” –––

const Preferences = struct {
    notifications: bool = false,
    theme: []const u8 = "",
    location: []const u8 = "",
    language: []const u8 = "",
    colorscheme: []const u8 = "",
    timezone: []const u8 = "",
    entertainment: Entertainment = .{},
    music: []const []const u8 = &.{},

    privacy: struct {
        shareData: bool = false,
        allowCookies: bool = false, // JSON had false
        marketingEmails: bool = false,
        trackingPreferences: struct {
            analytics: bool = false,
            crashReporting: bool = false,
            adPersonalization: bool = false,
        } = .{},
    } = .{},

    subscriptions: struct {
        newsletter: bool = false,
        premiumContent: bool = false,
        serviceEmails: struct {
            security: bool = false,
            productUpdates: bool = false,
            promotions: bool = false,
        } = .{},
    } = .{},
};

//––– Profile, with social_links as a keyed struct –––
const Profile = struct {
    first_name: []const u8 = "",
    last_name: []const u8 = "",
    bio: []const u8 = "",

    // these two were in your original but not in JSON—feel free to keep or drop
    avatar_url: []const u8 = "",
    website: []const u8 = "",

    social_links: struct {
        github: []const u8 = "",
        linkedin: []const u8 = "",
        twitter: []const u8 = "",
    } = .{},
};

//––– Top-level user data, now including history & system_metadata –––
pub const UserData = struct {
    id: []const u8 = "",
    username: []const u8 = "",
    email: []const u8 = "",
    preferences: Preferences = .{},
    age: i32 = 0,
    created_at: i64 = 0,
    last_login: i64 = 0, // not in your JSON but handy

    profile: Profile = .{},

    settings: struct {
        two_factor_enabled: bool = false,
        receive_newsletter: bool = false, // JSON had false
        default_view: []const u8 = "",
        accessibility: struct {
            highContrast: bool = false,
            reducedMotion: bool = false,
            screenReader: bool = false,
        } = .{},
    } = .{},

    history: struct {
        logins: []const struct {
            timestamp: i64,
            ip: []const u8,
            device: []const u8,
        } = &.{},
        recent_activity: []const struct {
            // “type” is a keyword in Zig, so we quote it
            type: []const u8,
            timestamp: i64,
        } = &.{},
    } = .{},

    system_metadata: struct {
        account_version: []const u8 = "",
        storage_used: []const u8 = "",
        last_backup: i64 = 0,
        client_info: struct {
            platform: []const u8 = "",
            browser: []const u8 = "",
            screen_resolution: []const u8 = "",
        } = .{},
    } = .{},
};

pub const user_data: UserData = .{
    .id = "983ypuhwefahpaw9e8hfgpahgfagj",
    .username = "johndoe",
    .email = "john@example.com",

    .preferences = Preferences{
        .notifications = true,
        .theme = "dark",
        .location = "Hell",
        .language = "english",
        .colorscheme = "dark-rainbow",
        .timezone = "",

        .entertainment = Entertainment{
            .movies = "The Brutalist",
            .books = &.{ "1984", "Brave New World", "Fahrenheit 451", "The Hitchhiker's Guide to the Galaxy", "Dune" },
            .games = &.{ "Cyberpunk 2077", "Baldur's Gate 3", "Elden Ring" },
            .tv_shows = &.{ "Breaking Bad", "True Detective", "The Wire" },
        },

        .music = &.{
            "Metallica",          "John Mayer",   "Pink Floyd",      "Radiohead",       "Tool",
            "Nine Inch Nails",    "The Beatles",  "David Bowie",     "Led Zeppelin",    "Nirvana",
            "Pearl Jam",          "Soundgarden",  "Alice in Chains", "R.E.M.",          "Depeche Mode",
            "The Cure",           "Joy Division", "New Order",       "The Smiths",      "Arcade Fire",
            "Interpol",           "The National", "Modest Mouse",    "Vampire Weekend", "Tame Impala",
            "St. Vincent",        "Grimes",       "FKA twigs",       "Kendrick Lamar",  "Frank Ocean",
            "Tyler, the Creator", "Kanye West",   "Lana Del Rey",
        },

        .privacy = .{
            .shareData = false,
            .allowCookies = false,
            .marketingEmails = false,
            .trackingPreferences = .{
                .analytics = false,
                .crashReporting = false,
                .adPersonalization = false,
            },
        },

        .subscriptions = .{
            .newsletter = false,
            .premiumContent = true,
            .serviceEmails = .{
                .security = true,
                .productUpdates = false,
                .promotions = false,
            },
        },
    },

    .age = 26,
    .created_at = 1741365455,

    .profile = Profile{
        .first_name = "John",
        .last_name = "Doe",
        .bio = "Senior software engineer with 8+ years of experience building distributed systems. Passionate about open source, functional programming, and system design. Currently working on high-performance API development at Tech Corp Inc. Avid reader, amateur photographer, and occasional mountain biker.",
        .social_links = .{
            .github = "https://github.com/johndoe",
            .linkedin = "https://linkedin.com/in/johndoe",
            .twitter = "https://twitter.com/johndoe",
        },
    },

    .settings = .{
        .two_factor_enabled = false,
        .receive_newsletter = false,
        .default_view = "",
        .accessibility = .{
            .highContrast = false,
            .reducedMotion = true,
            .screenReader = false,
        },
    },

    .history = .{
        .logins = &.{
            .{ .timestamp = 1741365455, .ip = "192.168.1.1", .device = "MacBook Pro 16-inch (M1)" },
            .{ .timestamp = 1741365454, .ip = "192.168.1.2", .device = "iPhone 15 Pro" },
        },
        .recent_activity = &.{
            .{ .type = "password_change", .timestamp = 1741365000 },
            .{ .type = "email_update", .timestamp = 1741364000 },
        },
    },

    .system_metadata = .{
        .account_version = "v2.3.1",
        .storage_used = "47MB",
        .last_backup = 1741360000,
        .client_info = .{
            .platform = "macOS 14.4",
            .browser = "Safari 17.3",
            .screen_resolution = "3456x2234",
        },
    },
};
