packer {
    required_plugins {
        tart = {
            version = ">= 1.12.0"
            source  = "github.com/cirruslabs/tart"
        }
    }
}

source "tart-cli" "tart" {
    from_ipsw    = "https://updates.cdn-apple.com/2025SpringFCS/fullrestores/082-16517/AACDDC33-9683-4431-98AF-F04EF7C15EE3/UniversalMac_15.4_24E248_Restore.ipsw"
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
        # Select Your Country or Region
        "<wait30s>czechia<leftShiftOn><tab><leftShiftOff><spacebar>",
        # Transfer Your Data to This Mac
        "<wait10s><tab><tab><tab><spacebar><tab><tab><spacebar>",
        # Written and Spoken Languages
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Accessibility
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Data & Privacy
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Create a Mac Account
        "<wait10s>Managed via Tart<tab>admin<tab>admin<tab>admin<tab><tab><spacebar><tab><tab><spacebar>",
        # Enable Voice Over
        "<wait120s><leftAltOn><f5><leftAltOff>",
        # Sign In with Your Apple ID
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Are you sure you want to skip signing in with an Apple ID?
        "<wait10s><tab><spacebar>",
        # Terms and Conditions
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # I have read and agree to the macOS Software License Agreement
        "<wait10s><tab><spacebar>",
        # Enable Location Services
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Are you sure you don't want to use Location Services?
        "<wait10s><tab><spacebar>",
        # Select Your Time Zone
        "<wait10s><tab><tab>UTC<enter><leftShiftOn><tab><tab><leftShiftOff><spacebar>",
        # Analytics
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Screen Time
        "<wait10s><tab><spacebar>",
        # Siri
        "<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Choose Your Look
        "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
        # Update Mac Automatically
        "<wait10s><tab><spacebar>",
        # Welcome to Mac
        "<wait10s><spacebar>",
        # Disable Voice Over
        "<leftAltOn><f5><leftAltOff>",
        # Enable Keyboard navigation
        # This is so that we can navigate the System Settings app using the keyboard
        "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
        "<wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
        "<wait10s><leftAltOn>q<leftAltOff>",
        # Now that the installation is done, open "System Settings"
        "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
        # Navigate to "Sharing"
        "<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Sharing<enter>",
        # Navigate to "Screen Sharing" and enable it
        "<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",
        # Navigate to "Remote Login" and enable it
        "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
        # Quit System Settings
        "<wait10s><leftAltOn>q<leftAltOff>",
        # Disable Gatekeeper (1/2)
        "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
        "<wait10s>sudo spctl --global-disable<enter>",
        "<wait10s>admin<enter>",
        "<wait10s><leftAltOn>q<leftAltOff>",
        # Disable Gatekeeper (2/2)
        "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
        "<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Privacy & Security<enter>",
        "<wait10s><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff>",
        "<wait10s><down><wait1s><down><wait1s><enter>",
        "<wait10s>admin<enter>",
        "<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",
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