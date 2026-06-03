Config = {}

-- The command used to open the Premium Telecom Authority admin panel
Config.CommandName = "phone"

-- The permission level required to open the admin panel
Config.AdminPermission = "admin" -- Options: "admin", "god", etc.

-- Interval in minutes to check database for expired premium numbers
Config.ExpiryCheckInterval = 60 

-- Minimum and Maximum length of the custom phone number
Config.MinPhoneNumberLength = 3
Config.MaxPhoneNumberLength = 6


-- Allow alphanumeric characters in custom phone numbers? (e.g. 555-GET-CASH)
Config.AllowAlphanumeric = true

-- Debug prints in server console
Config.Debug = true

-- Notification Settings
Config.Notify = {
    -- Duration in milliseconds
    Duration = 5000,
    
    -- Types: 'primary', 'success', 'error'
    Types = {
        Success = 'success',
        Error = 'error',
        Info = 'primary'
    }
}
