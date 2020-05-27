job "webpagecounter" {
    datacenters = ["hashistack1"]
    type        = "service"

    group "webcountergroup" {
      count = 4
      task "deploy-webcounters" {
        driver = "raw_exec"
        config {
            command = "/usr/local/bin/webcounter"
            args = [  "-port=${NOMAD_PORT_http}", 
                      "-ip=0.0.0.0", 
                      "-consulACL=9507d4cd-b9ff-178d-ed3c-33ce194e0095", 
                      "-consulIP=192.168.9.11:8321",
                      "-consulcert=<DEPLOYMENT SCRIPTS PUT CORRECT VALUE HERE>",
                      "-consulkey=<DEPLOYMENT SCRIPTS PUT CORRECT VALUE HERE>",
                      "-consulCA=<DEPLOYMENT SCRIPTS PUT CORRECT VALUE HERE>",
                      "-vaultcert=<DEPLOYMENT SCRIPTS PUT CORRECT VALUE HERE>",
                      "-vaultkey=<DEPLOYMENT SCRIPTS PUT CORRECT VALUE HERE>",
                      "-vaultCA=<DEPLOYMENT SCRIPTS PUT CORRECT VALUE HERE>"]
        }
        resources {
          cpu    = 20
          memory = 60
          network {
            port "http" {}
          }
        }
        service {
          name = "webpagecounter"
          port = "http"
          check {
            name     = "health-check-webpagecounter-${NOMAD_PORT_http}"
            type     = "http"
            path     = "/health"
            interval = "10s"
            timeout  = "2s"
          }
          check {
            type     = "script"
            name     = "scripted-check-webpagecounter-${NOMAD_PORT_http}"
            command  = "/usr/local/bin/consul_goapp_verify.sh"
            args     = ["http://127.0.0.1:${NOMAD_PORT_http}/health"]
            interval = "60s"
            timeout  = "5s"

            check_restart {
              limit = 3
              grace = "90s"
              ignore_warnings = false
            }
          }
        }
      }
    }
}
