{ ... }:
{
  # Only settings the source machine actually has. Adding defaults it never set
  # (key repeat rate, Finder tweaks) would change how the machine feels, which
  # the spec rules out.
  system.defaults = {
    dock = {
      autohide = true;
      tilesize = 64;
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
    };
  };
}
