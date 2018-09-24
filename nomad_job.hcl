job "webpagecounter" {
    datacenters = ["dc1"]
    type        = "service"

    group "webcountergroup-a" {
      constraint {
        distinct_hosts = true
      }
      count = 0
      task "deploy-webcounters-a" {
        driver = "raw_exec"
        config {
            command = "/usr/local/bin/webcounter"
            args = ["-port=${NOMAD_PORT_http}", "-ip=0.0.0.0","-templates=/usr/local/bin/templates/*.html"]
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
      group "webcountergroup-b" {
      count = 0
      task "deploy-webcounters-b" {
        driver = "raw_exec"
        config {
            command = "/usr/local/bin/webcounter"
            args = ["-port=${NOMAD_PORT_http}", "-ip=0.0.0.0"]
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
