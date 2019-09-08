# Application Workflow with Nomad - Overview

![image](https://user-images.githubusercontent.com/9472095/54201416-e572c800-44cd-11e9-9b3c-795d3df1bdbc.png)

## Challenge

![image](https://user-images.githubusercontent.com/9472095/54204236-181fbf00-44d4-11e9-8b4b-ca2e570bb501.png)

## Solution

![image](https://user-images.githubusercontent.com/9472095/54204270-2b328f00-44d4-11e9-9fbe-20506892da73.png)

## Nomad for application scheduling a.k.a. bin packing

![image](https://user-images.githubusercontent.com/9472095/43806561-585eb1d0-9a9c-11e8-9f03-e0a4282e8d3d.png)

Finally, [Nomad](https://www.nomadproject.io/) has been used to schedule the application deployment. Nomad can deploy any application at any scale on any cloud :)
It's uses a declarative syntax and will ensure that the required number of applications requested are maintained. This is why I put the crash button on the application - you can have some simple fun killing the application and watching Nomad resurrect it.

``` hcl
job "webpagecounter" {
    datacenters = ["dc1"]
    type        = "service"

    group "webcountergroup" {
      count = 4
      task "deploy-webcounters" {
        driver = "raw_exec"
        config {
            command = "/usr/local/bin/webcounter"
            args = ["-port=${NOMAD_PORT_http}", "-ip=0.0.0.0", "-consulACL=a2f24f63-6dae-799e-5529-f6cfd31982ef", "-consulIp=192.168.9.120:8321"]
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
```

[:back:](../../ReadMe.md)