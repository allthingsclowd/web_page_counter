``` bash
==> web-page-counter-vmware: Destroying virtual machine...
2019/09/09 23:00:51 packer: 2019/09/09 23:00:51 [DEBUG] Opening new ssh session
2019/09/09 23:00:51 packer: 2019/09/09 23:00:51 [DEBUG] starting remote command: vim-cmd vmsvc/destroy 60
2019/09/09 23:00:52 packer: 2019/09/09 23:00:52 [DEBUG] Opening new ssh session
2019/09/09 23:00:52 packer: 2019/09/09 23:00:52 [DEBUG] starting remote command: test ! -e "/vmfs/volumes/IntelDS2/web-page-counter"
2019/09/09 23:00:52 packer: 2019/09/09 23:00:52 [DEBUG] Opening new ssh session
2019/09/09 23:00:52 packer: 2019/09/09 23:00:52 [DEBUG] starting remote command: test -e "/vmfs/volumes/IntelDS2/web-page-counter"
2019/09/09 23:00:52 packer: 2019/09/09 23:00:52 [ERROR] Remote command exited with '1': test -e "/vmfs/volumes/IntelDS2/web-page-counter"
2019/09/09 23:00:52 [INFO] (telemetry) ending vmware-iso
2019/09/09 23:00:52 ui error: Build 'web-page-counter-vmware' errored: Error compacting disk: 'vmkfstools --punchzero "/vmfs/volumes/IntelDS2/web-page-counter/disk.vmdk"'

Stdout: vmfsDisk: 1, rdmDisk: 0, blockSize: 1048576
Hole Punching: 6% doBuild 'web-page-counter-vmware' errored: Error compacting disk: 'vmkfstools --punchzero "/vmfs/volumes/IntelDS2/web-page-counter/disk.vmdk"'
Hole Punching: 75% done.

Stderr:

2019/09/09 23:00:52 machine readable: error-count []string{"1"}
2019/09/09 23:00:52 ui error:
==> Some builds didn't complete successfully and had errors:
Stdout: vmfsDisk: 1, rdmDisk: 0, blockSize: 1048576
2019/09/09 23:00:52 machine readable: web-page-counter-vmware,error []string{"Error compacting disk: 'vmkfstools --punchzero \"/vmfs/volumes/IntelDS2/web-page-counter/disk.vmdk\"'\n\nStdout: vmfsDisk: 1, rdmDisk: 0, blockSize: 1048576\n\rHole Punching: 0% done.\rHole Punching: 1% done.\rHole Punching: 2% done.\rHole Punching: 3% done.\rHole Punching: 4% done.\rHole Punching: 5% done.\rHole Punching: 6% done.\rHole Punching: 7% done.\rHole Punching: 8% done.\rHole Punching: 9% done.\rHole Punching: 10% done.\rHole Punching: 11% done.\rHole Punching: 12% done.\rHole Punching: 13% done.\rHole Punching: 14% done.\rHole Punching: 15% done.\rHole Punching: 16% done.\rHole Punching: 17% done.\rHole Punching: 18% done.\rHole Punching: 19% done.\rHole Punching: 20% done.\rHole Punching: 21% done.\rHole Punching: 22% done.\rHole Punching: 23% done.\rHole Punching: 24% done.\rHole Punching: 25% done.\rHole Punching: 26% done.\rHole Punching: 27% done.\rHole Punching: 28% done.\rHole Punching: 29% done.\rHole Punching: 30% done.\rHole Punching: 31% done.\rHole Punching: 32% done.\rHole Punching: 33% done.\rHole Punching: 34% done.\rHole Punching: 35% done.\rHole Punching: 36% done.\rHole Punching: 37% done.\rHole Punching: 38% done.\rHole Punching: 39% done.\rHole Punching: 40% done.\rHole Punching: 41% done.\rHole Punching: 42% done.\rHole Punching: 43% done.\rHole Punching: 44% done.\rHole Punching: 45% done.\rHole Punching: 46% done.\rHole Punching: 47% done.\rHole Punching: 48% done.\rHole Punching: 49% done.\rHole Punching: 50% done.\rHole Punching: 51% done.\rHole Punching: 52% done.\rHole Punching: 53% done.\rHole Punching: 54% done.\rHole Punching: 55% done.\rHole Punching: 56% done.\rHole Punching: 57% done.\rHole Punching: 58% done.\rHole Punching: 59% done.\rHole Punching: 60% done.\rHole Punching: 61% done.\rHole Punching: 62% done.\rHole Punching: 63% done.\rHole Punching: 64% done.\rHole Punching: 65% done.\rHole Punching: 66% done.\rHole Punching: 67% done.\rHole Punching: 68% done.\rHole Punching: 69% done.\rHole Punching: 70% done.\rHole Punching: 71% done.\rHole Punching: 72% done.\rHole Punching: 73% done.\rHole Punching: 74% done.\rHole Punching: 75% done.\n\nStderr: "}
2019/09/09 23:00:52 ui error: --> web-page-counter-vmware: Error compacting disk: 'vmkfstools --punchzero "/vmfs/volumes/IntelDS2/web-page-counter/disk.vmdk"'

Stdout: vmfsDisk: 1, rdmDisk: 0, blockSize: 1048576
Hole Punching: 75% done.

Stderr:
==> Builds finished but no artifacts were created.
2019/09/09 23:00:52 [INFO] (telemetry) Finalizing.
Hole Punching: 75% done.

Stderr:

==> Some builds didn't complete successfully and had errors:
--> web-page-counter-vmware: Error compacting disk: 'vmkfstools --punchzero "/vmfs/volumes/IntelDS2/web-page-counter/disk.vmdk"'

Stdout: vmfsDisk: 1, rdmDisk: 0, blockSize: 1048576
Hole Punching: 75% done.

Stderr:

==> Builds finished but no artifacts were created.
2019/09/09 23:00:52 waiting for all plugin processes to complete...
2019/09/09 23:00:52 /usr/local/bin/packer: plugin process exited
2019/09/09 23:00:52 /usr/local/bin/packer: plugin process exited
2019/09/09 23:00:52 /usr/local/bin/packer: plugin process exited
2019/09/09 23:00:52 /usr/local/bin/packer: plugin process exited
2019/09/09 23:00:52 /usr/local/bin/packer: plugin process exited
2019/09/09 23:00:52 /usr/local/bin/packer: plugin process exited
2019/09/09 23:00:52 [ERR] Error decoding response stream 7: EOF
~/vagrant_workspace/pipeline/packer (update_golang_template)
```
