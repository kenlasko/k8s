[Falco](https://github.com/falcosecurity/falco) is a cloud native runtime security tool for Linux operating systems. It is designed to detect and alert on abnormal behavior and potential security threats in real-time.

Good idea in theory, but was very chatty and verbose and provided very little benefit for my circumstances. I spent more time creating alert exclusions than actually using it. 

It also made use of [Fluent Bit](/fluentbit) for getting logs from Talos. Both are currently disabled.