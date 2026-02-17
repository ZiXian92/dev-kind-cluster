data "kubernetes_config_map_v1" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}

locals {
  coredns_hosts_block = <<EOT
    hosts {
%{for line in [
  "10.96.253.184 coder.localtest.me",
]~}
      ${line}
%{endfor~}
      fallthrough
    }
    EOT
}

# This regex pattern matches the "ready" block in the CoreDNS configuration file.
# It captures the ready zone configuration and any associated hosts blocks.
#
# Regex breakdown:
# \n           - Matches a literal newline character
# \\s+         - Matches one or more whitespace characters (escaped backslash for Terraform string)
# ready        - Matches the literal string "ready"
# \n           - Matches another literal newline character
# (?:          - Starts a non-capturing group (the ?: means it doesn't create a capture group)
#   \\s+       - Matches one or more whitespace characters
#   hosts      - Matches the literal string "hosts"
#   \\s*       - Matches zero or more whitespace characters
#   {[^}]*}    - Matches a pair of curly braces with any content inside except closing braces
# )*           - End of non-capturing group, repeated zero or more times (making hosts blocks optional)
#
# The function regexall() returns all non-overlapping matches of this pattern in the Corefile data.
resource "kubernetes_config_map_v1" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  data = {
    "Corefile" = replace(
      data.kubernetes_config_map_v1.coredns.data["Corefile"],
      regexall("\n\\s+ready\n(?:\\s+hosts\\s*{[^}]*}\n)*", data.kubernetes_config_map_v1.coredns.data["Corefile"])[0],
      "\n    ready\n${local.coredns_hosts_block}",
    )
  }
}

import {
  id = "kube-system/coredns"
  to = kubernetes_config_map_v1.coredns
}
