packer {
    required_plugins {
        tart = {
            version = ">= 1.12.0"
            source  = "github.com/cirruslabs/tart"
        }
    }
}

source "tart-cli" "tart" {
    from_ipsw    = "https://updates.cdn-apple.com/2025WinterFCS/fullrestores/072-70618/42F1A8CC-7E07-4329-958A-757FF600C303/UniversalMac_15.3.1_24D70_Restore.ipsw"
    vm_name      = "macos-base"
    cpu_count    = 4
    memory_gb    = 8
    disk_size_gb = 40
    ssh_password = "admin"
    ssh_username = "admin"
    ssh_timeout  = "120s"
    headless     = true
    boot_command = [
        # hello, hola, bonjour, etc.
        "<wait60s><spacebar>",
        # Language: most of the times we have a list of "English"[1], "English (UK)", etc. with
        # "English" language already selected. If we type "english", it'll cause us to switch
        # to the "English (UK)", which is not what we want. To solve this, we switch to some other
        # language first, e.g. "Italiano" and then switch back to "English". We'll then jump to the
        # first entry in a list of "english"-prefixed items, which will be "English".
        #
        # [1]: should be named "English (US)", but oh well 🤷
        "<wait30s>italiano<esc>english<enter>",
        # Select Your Country and Region
        "<wait30s>czechia<leftShiftOn><tab><leftShiftOff><spacebar>",
        # Written and Spoken Languages
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Accessibility
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Data & Privacy
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Migration Assistant
        "<wait10s><tab><tab><tab><spacebar>",
        # Sign In with Your Apple ID
        "<wait10s><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Are you sure you want to skip signing in with an Apple ID?
        "<wait10s><tab><spacebar>",
        # Terms and Conditions
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # I have read and agree to the macOS Software License Agreement
        "<wait10s><tab><spacebar>",
        # Create a Computer Account
        "<wait10s>admin<tab><tab>admin<tab>admin<tab><tab><tab><spacebar>",
        # Enable Location Services
        "<wait30s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Are you sure you don't want to use Location Services?
        "<wait10s><tab><spacebar>",
        # Select Your Time Zone
        "<wait10s><tab><tab>Prague<enter><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Analytics
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Screen Time
        "<wait10s><tab><spacebar>",
        # Siri
        "<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Choose Your Look
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Welcome to Mac
        "<wait10s><spacebar>",
        # Enable Keyboard navigation
        # This is so that we can navigate the System Settings app using the keyboard
        "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
        "<wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
        "<wait10s><leftAltOn>q<leftAltOff>",
        # Now that the installation is done, open "System Settings"
        "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
        # Navigate to "Sharing"
        "<wait10s><leftAltOn>f<leftAltOff>sharing<enter>",
        # Navigate to "Screen Sharing" and enable it
        "<wait10s><tab><tab><tab><tab><tab><spacebar>",
        # Navigate to "Remote Login" and enable it
        "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
        # Quit System Settings
        "<wait10s><leftAltOn>q<leftAltOff>",
    ]

    // A (hopefully) temporary workaround for Virtualization.Framework's
    // installation process not fully finishing in a timely manner
    create_grace_time = "30s"
}

build {
    sources = ["source.tart-cli.tart"]

    provisioner "shell" {
        inline = [
            // Enable passwordless sudo
            "echo admin | sudo -S sh -c \"mkdir -p /etc/sudoers.d/; echo 'admin ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/admin-nopasswd\"",
            // Enable auto-login
            //
            // See https://github.com/xfreebird/kcpassword for details.
            "echo '00000000: 1ced 3f4a bcbc ba2c caca 4e82' | sudo xxd -r - /etc/kcpassword",
            "sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser admin",
            // Set timezone to Prague
            "sudo systemsetup -settimezone 'Europe/Prague'",
            // Disable screensaver at login screen
            "sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 0",
            // Disable screensaver for admin user
            "defaults -currentHost write com.apple.screensaver idleTime 0",
            // Prevent the VM from sleeping
            "sudo systemsetup -setdisplaysleep Off",
            "sudo systemsetup -setsleep Off",
            "sudo systemsetup -setcomputersleep Off",
            // Disable screen lock
            //
            // Note that this only works if the user is logged-in,
            // i.e. not on login screen.
            "sysadminctl -screenLock off -password admin",
        ]
    }

    provisioner "shell" {
        inline = [
            "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
            "echo \"export LANG=en_US.UTF-8\" >> ~/.zprofile",
            "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile",
            "echo \"export HOMEBREW_NO_AUTO_UPDATE=1\" >> ~/.zprofile",
            "echo \"export HOMEBREW_NO_INSTALL_CLEANUP=1\" >> ~/.zprofile",
            "source ~/.zprofile",
            "brew --version",
            "brew update",
            "brew install wget cmake gcc git-lfs jq gh gitlab-runner",
            "git lfs install",
        ]
    }

    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install libyaml rbenv", # https://github.com/rbenv/ruby-build/discussions/2118
            "echo 'if which rbenv > /dev/null; then eval \"$(rbenv init -)\"; fi' >> ~/.zprofile",
            "source ~/.zprofile",
            "rbenv install 3.1.4",
            "rbenv global 3.1.4",
            "gem install bundler",
        ]
    }
}