$ErrorActionPreference = "Stop"
$targetDir = Join-Path $env:USERPROFILE "Zvuk to CZ"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Write-Host "=== Mumble do CZ - instalace (NVIDIA GPU) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cilova slozka: $targetDir"
Write-Host ""
Write-Host "0) Rozbaluji soubory..."
$files = @{
    'stop.bat' = 'QGVjaG8gb2ZmCnBvd2Vyc2hlbGwgLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJX5kcDBzdG9wX2hlbHBlci5wczEiCmVjaG8uCnBhdXNlCg=='
    'start_helper.ps1' = 'JHBpZEZpbGUgPSBKb2luLVBhdGggJFBTU2NyaXB0Um9vdCAienZ1a2N6LnBpZCIKCmlmIChUZXN0LVBhdGggJHBpZEZpbGUpIHsKICAgICRvbGRQaWQgPSBHZXQtQ29udGVudCAkcGlkRmlsZQogICAgaWYgKCRvbGRQaWQgLWFuZCAoR2V0LVByb2Nlc3MgLUlkICRvbGRQaWQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7CiAgICAgICAgV3JpdGUtSG9zdCAiU2tyaXB0IHV6IGJlemkgKFBJRCAkb2xkUGlkKS4gUHJvIHJlc3RhcnQgbmVqZHJpdiBzcHVzdCBzdG9wLmJhdC4iCiAgICAgICAgZXhpdAogICAgfQp9CgokcnVuUHMxID0gSm9pbi1QYXRoICRQU1NjcmlwdFJvb3QgInJ1bi5wczEiCiRhcmdMaXN0ID0gIi1Ob0V4aXQgLUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLUZpbGUgYCIkcnVuUHMxYCIiCiRwcm9jID0gU3RhcnQtUHJvY2VzcyAtRmlsZVBhdGggInBvd2Vyc2hlbGwiIC1Bcmd1bWVudExpc3QgJGFyZ0xpc3QgLVBhc3NUaHJ1CgokcHJvYy5JZCB8IE91dC1GaWxlIC1FbmNvZGluZyBhc2NpaSAkcGlkRmlsZQpXcml0ZS1Ib3N0ICJTcHVzdGVubyAoUElEICQoJHByb2MuSWQpKS4iCg=='
    'stop_helper.ps1' = 'JHBpZEZpbGUgPSBKb2luLVBhdGggJFBTU2NyaXB0Um9vdCAienZ1a2N6LnBpZCIKCmlmICgtbm90IChUZXN0LVBhdGggJHBpZEZpbGUpKSB7CiAgICBXcml0ZS1Ib3N0ICJTa3JpcHQgbmVuaSBzcHVzdGVueSAoY2h5YmkgUElEIHNvdWJvcikuIgogICAgZXhpdAp9CgokdGFyZ2V0UGlkID0gR2V0LUNvbnRlbnQgJHBpZEZpbGUKCmlmICgkdGFyZ2V0UGlkIC1hbmQgKEdldC1Qcm9jZXNzIC1JZCAkdGFyZ2V0UGlkIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgewogICAgIyBuYWpkaSBjZWx5IHN0cm9tIHBvdG9ta3UgKHB5dGhvbi5leGUgdW1pIHphbG96aXQgZGFsc2kgdm5vcmVueSBwcm9jZXMpCiAgICAkYWxsUHJvY3MgPSBHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUHJvY2VzcwogICAgJHRvS2lsbCA9IFtTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W2ludF1dOjpuZXcoKQogICAgJGZyb250aWVyID0gW1N5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3RbaW50XV06Om5ldygpCiAgICAkZnJvbnRpZXIuQWRkKFtpbnRdJHRhcmdldFBpZCkKICAgIHdoaWxlICgkZnJvbnRpZXIuQ291bnQgLWd0IDApIHsKICAgICAgICAkY3VycmVudCA9ICRmcm9udGllclswXQogICAgICAgICRmcm9udGllci5SZW1vdmVBdCgwKQogICAgICAgICR0b0tpbGwuQWRkKCRjdXJyZW50KQogICAgICAgICRhbGxQcm9jcyB8IFdoZXJlLU9iamVjdCB7ICRfLlBhcmVudFByb2Nlc3NJZCAtZXEgJGN1cnJlbnQgfSB8IEZvckVhY2gtT2JqZWN0IHsKICAgICAgICAgICAgJGZyb250aWVyLkFkZChbaW50XSRfLlByb2Nlc3NJZCkKICAgICAgICB9CiAgICB9CiAgICAjIG5lamRyaXYgbmVqaGx1YnNpIHBvdG9ta3ksIHBhayByb2RpY2UKICAgIFthcnJheV06OlJldmVyc2UoJHRvS2lsbCkKICAgIGZvcmVhY2ggKCRwcm9jSWQgaW4gJHRvS2lsbCkgewogICAgICAgIFN0b3AtUHJvY2VzcyAtSWQgJHByb2NJZCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIH0KICAgIFdyaXRlLUhvc3QgIlphc3RhdmVubyAoUElEICR0YXJnZXRQaWQgKyAkKCR0b0tpbGwuQ291bnQgLSAxKSBwb3RvbWt1KS4iCn0gZWxzZSB7CiAgICBXcml0ZS1Ib3N0ICJTa3JpcHQgdXogbmViZXplbC4iCn0KClJlbW92ZS1JdGVtICRwaWRGaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCg=='
    'loopback_translator.py' = 'IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiIKU3lzdMOpbW92w70genZ1ayAoV0FTQVBJIGxvb3BiYWNrKSAtPiBwxZllcGlzIChXaGlzcGVyKSAtPiBwxZlla2xhZCBkbyDEjWXFoXRpbnkuCgpCZXJlIHRvLCBjbyBocmFqZSBuYSB2w71zdHVwdSB6dnVrb3bDqSBrYXJ0eSwgdGFrxb5lIGZ1bmd1amUgbmEgTXVtYmxlLApEaXNjb3JkLCBZb3VUdWJlLCBjb2tvbGl2LiBNbHV2xI3DrSBhbGUgbmVqc291IG9kZMSbbGVuw60gLSB2xaFlY2hubyBwxZlpamRlCnNtw61jaGFuw6kgZG9ocm9tYWR5LgoKSW5zdGFsYWNlIChqZW4gV2luZG93cyk6CiAgICBwaXAgaW5zdGFsbCBQeUF1ZGlvV1BhdGNoIGZhc3Rlci13aGlzcGVyIG51bXB5IHNjaXB5IGRlZXBsCgpTcHXFoXTEm27DrToKICAgIHNldCBERUVQTF9LRVk9Li4uICAgICAgICAjIHZvbGl0ZWxuw6ksIGJleiBrbMOtxI1lIHNlIGplbiBwxZllcGlzdWplCiAgICBweXRob24gbG9vcGJhY2tfdHJhbnNsYXRvci5weQoiIiIKCmltcG9ydCBvcwppbXBvcnQgcXVldWUKaW1wb3J0IHN5c2NvbmZpZwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCgpmb3IgX3BrZyBpbiAoImN1YmxhcyIsICJjdWRubiIpOgogICAgX2JpbiA9IG9zLnBhdGguam9pbihzeXNjb25maWcuZ2V0X3BhdGhzKClbInB1cmVsaWIiXSwgIm52aWRpYSIsIF9wa2csICJiaW4iKQogICAgaWYgb3MucGF0aC5pc2RpcihfYmluKToKICAgICAgICBvcy5hZGRfZGxsX2RpcmVjdG9yeShfYmluKQogICAgICAgIG9zLmVudmlyb25bIlBBVEgiXSA9IF9iaW4gKyBvcy5wYXRoc2VwICsgb3MuZW52aXJvblsiUEFUSCJdCgppbXBvcnQgbnVtcHkgYXMgbnAKaW1wb3J0IHB5YXVkaW93cGF0Y2ggYXMgcHlhdWRpbwpmcm9tIHNjaXB5LnNpZ25hbCBpbXBvcnQgcmVzYW1wbGVfcG9seQpmcm9tIGZhc3Rlcl93aGlzcGVyIGltcG9ydCBXaGlzcGVyTW9kZWwKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBuYXN0YXZlbsOtCgpXSElTUEVSX1JBVEUgPSAxNjAwMApDSFVOSyA9IDEwMjQKClNJTEVOQ0VfUk1TID0gMC4wMDQgICAjIHBvZCB0b3V0byBobGFzaXRvc3TDrSB0byBiZXJ1IGpha28gdGljaG8KU0lMRU5DRV9HQVAgPSAwLjggICAgICMgcyB0aWNoYSA9IGtvbmVjIHByb21sdXZ5Ck1JTl9TUEVFQ0ggPSAwLjQgICAgICAjIGtyYXTFocOtIMO6c2VreSB6YWhvZMOtbQpNQVhfU1BFRUNIID0gMTUuMCAgICAgIyBkZWzFocOtIHByb21sdXZ1IHJvenNla251CgpNT0RFTF9TSVpFID0gInNtYWxsIiAgIyB0aW55IC8gYmFzZSAvIHNtYWxsIC8gbWVkaXVtIC8gbGFyZ2UtdjMKREVWSUNFID0gImN1ZGEiICAgICAgICMgImNwdSIgcG9rdWQgYnkgR1BVIGTEm2xhbG8gcHJvYmzDqW15CkNPTVBVVEUgPSAiZmxvYXQxNiIgICAjIG5hIENQVSBzcMOtxaEgImludDgiCgp3b3JrX3F1ZXVlOiBxdWV1ZS5RdWV1ZSA9IHF1ZXVlLlF1ZXVlKCkKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBwxZlla2xhZAoKX2RlZXBsID0gTm9uZQppZiBvcy5nZXRlbnYoIkRFRVBMX0tFWSIpOgogICAgaW1wb3J0IGRlZXBsCiAgICBfZGVlcGwgPSBkZWVwbC5UcmFuc2xhdG9yKG9zLmVudmlyb25bIkRFRVBMX0tFWSJdKQoKCmRlZiB0b19jemVjaCh0ZXh0OiBzdHIpIC0+IHN0cjoKICAgIGlmIG5vdCBfZGVlcGw6CiAgICAgICAgcmV0dXJuIHRleHQKICAgIHRyeToKICAgICAgICByZXR1cm4gX2RlZXBsLnRyYW5zbGF0ZV90ZXh0KHRleHQsIHRhcmdldF9sYW5nPSJDUyIpLnRleHQKICAgIGV4Y2VwdCBFeGNlcHRpb24gYXMgZXhjOgogICAgICAgIHByaW50KGYiW3DFmWVrbGFkIHNlbGhhbDoge2V4Y31dIikKICAgICAgICByZXR1cm4gdGV4dAoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSB6ZHJvaiB6dnVrdQoKZGVmIGZpbmRfbG9vcGJhY2socCk6CiAgICAiIiJOYWpkZSBsb29wYmFjayB6YcWZw616ZW7DrSBvZHBvdsOtZGFqw61jw60gYWt0dcOhbG7DrW11IHbDvXN0dXB1LiIiIgogICAgd2FzYXBpID0gcC5nZXRfaG9zdF9hcGlfaW5mb19ieV90eXBlKHB5YXVkaW8ucGFXQVNBUEkpCiAgICBzcGVha2VycyA9IHAuZ2V0X2RldmljZV9pbmZvX2J5X2luZGV4KHdhc2FwaVsiZGVmYXVsdE91dHB1dERldmljZSJdKQoKICAgIGlmIHNwZWFrZXJzLmdldCgiaXNMb29wYmFja0RldmljZSIpOgogICAgICAgIHJldHVybiBzcGVha2VycwoKICAgIGZvciBsYiBpbiBwLmdldF9sb29wYmFja19kZXZpY2VfaW5mb19nZW5lcmF0b3IoKToKICAgICAgICBpZiBzcGVha2Vyc1sibmFtZSJdIGluIGxiWyJuYW1lIl06CiAgICAgICAgICAgIHJldHVybiBsYgoKICAgIHJhaXNlIFJ1bnRpbWVFcnJvcigKICAgICAgICAiTG9vcGJhY2sgemHFmcOtemVuw60gbmVuYWxlemVuby4gWmtvbnRyb2x1aiwgxb5lIG3DocWhIHZlIFdpbmRvd3MgIgogICAgICAgICJuYXN0YXZlbsO9IHNwcsOhdm7DvSB2w71zdHVwIHp2dWt1LiIKICAgICkKCgpkZWYgY2FwdHVyZSgpOgogICAgd2l0aCBweWF1ZGlvLlB5QXVkaW8oKSBhcyBwOgogICAgICAgIGRldiA9IGZpbmRfbG9vcGJhY2socCkKICAgICAgICByYXRlID0gaW50KGRldlsiZGVmYXVsdFNhbXBsZVJhdGUiXSkKICAgICAgICBjaGFubmVscyA9IGludChkZXZbIm1heElucHV0Q2hhbm5lbHMiXSkKICAgICAgICBwcmludChmIlBvc2xvdWNow6FtOiB7ZGV2WyduYW1lJ119ICAoe3JhdGV9IEh6LCB7Y2hhbm5lbHN9IGthbsOhbMWvKVxuIikKCiAgICAgICAgc3RyZWFtID0gcC5vcGVuKAogICAgICAgICAgICBmb3JtYXQ9cHlhdWRpby5wYUludDE2LAogICAgICAgICAgICBjaGFubmVscz1jaGFubmVscywKICAgICAgICAgICAgcmF0ZT1yYXRlLAogICAgICAgICAgICBmcmFtZXNfcGVyX2J1ZmZlcj1DSFVOSywKICAgICAgICAgICAgaW5wdXQ9VHJ1ZSwKICAgICAgICAgICAgaW5wdXRfZGV2aWNlX2luZGV4PWRldlsiaW5kZXgiXSwKICAgICAgICApCgogICAgICAgIGNodW5rcyA9IFtdCiAgICAgICAgbGFzdF9zb3VuZCA9IDAuMAogICAgICAgIHNwZWFraW5nID0gRmFsc2UKCiAgICAgICAgZGVmIGZsdXNoKCk6CiAgICAgICAgICAgIG5vbmxvY2FsIGNodW5rcywgc3BlYWtpbmcKICAgICAgICAgICAgaWYgbm90IGNodW5rczoKICAgICAgICAgICAgICAgIHJldHVybgogICAgICAgICAgICByYXcgPSBiIiIuam9pbihjaHVua3MpCiAgICAgICAgICAgIGNodW5rcyA9IFtdCiAgICAgICAgICAgIHNwZWFraW5nID0gRmFsc2UKICAgICAgICAgICAgYXVkaW8gPSBucC5mcm9tYnVmZmVyKHJhdywgZHR5cGU9bnAuaW50MTYpLmFzdHlwZShucC5mbG9hdDMyKSAvIDMyNzY4LjAKICAgICAgICAgICAgaWYgY2hhbm5lbHMgPiAxOgogICAgICAgICAgICAgICAgYXVkaW8gPSBhdWRpby5yZXNoYXBlKC0xLCBjaGFubmVscykubWVhbihheGlzPTEpCiAgICAgICAgICAgIGlmIGxlbihhdWRpbykgLyByYXRlIDwgTUlOX1NQRUVDSDoKICAgICAgICAgICAgICAgIHJldHVybgogICAgICAgICAgICB3b3JrX3F1ZXVlLnB1dChyZXNhbXBsZV9wb2x5KGF1ZGlvLCBXSElTUEVSX1JBVEUsIHJhdGUpKQoKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICBkYXRhID0gc3RyZWFtLnJlYWQoQ0hVTkssIGV4Y2VwdGlvbl9vbl9vdmVyZmxvdz1GYWxzZSkKICAgICAgICAgICAgYmxvY2sgPSBucC5mcm9tYnVmZmVyKGRhdGEsIGR0eXBlPW5wLmludDE2KS5hc3R5cGUobnAuZmxvYXQzMikgLyAzMjc2OC4wCiAgICAgICAgICAgIHJtcyA9IGZsb2F0KG5wLnNxcnQobnAubWVhbihibG9jayAqKiAyKSkpCiAgICAgICAgICAgIG5vdyA9IHRpbWUudGltZSgpCgogICAgICAgICAgICBpZiBybXMgPiBTSUxFTkNFX1JNUzoKICAgICAgICAgICAgICAgIGNodW5rcy5hcHBlbmQoZGF0YSkKICAgICAgICAgICAgICAgIGxhc3Rfc291bmQgPSBub3cKICAgICAgICAgICAgICAgIHNwZWFraW5nID0gVHJ1ZQogICAgICAgICAgICBlbGlmIHNwZWFraW5nOgogICAgICAgICAgICAgICAgY2h1bmtzLmFwcGVuZChkYXRhKSAgICMga3LDoXRrw6kgcGF1enkgdXZuaXTFmSB2xJt0eSBzaSBuZWNow6FtCiAgICAgICAgICAgICAgICBpZiBub3cgLSBsYXN0X3NvdW5kID49IFNJTEVOQ0VfR0FQOgogICAgICAgICAgICAgICAgICAgIGZsdXNoKCkKCiAgICAgICAgICAgIGlmIHNwZWFraW5nOgogICAgICAgICAgICAgICAgZHVyID0gc3VtKGxlbihjKSBmb3IgYyBpbiBjaHVua3MpIC8gMiAvIGNoYW5uZWxzIC8gcmF0ZQogICAgICAgICAgICAgICAgaWYgZHVyID49IE1BWF9TUEVFQ0g6CiAgICAgICAgICAgICAgICAgICAgZmx1c2goKQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBwxZllcGlzCgpkZWYgdHJhbnNjcmliZXIoKToKICAgIG1vZGVsID0gV2hpc3Blck1vZGVsKE1PREVMX1NJWkUsIGRldmljZT1ERVZJQ0UsIGNvbXB1dGVfdHlwZT1DT01QVVRFKQogICAgcHJpbnQoIk1vZGVsIG5hxI10ZW4uXG4iKQoKICAgIHdoaWxlIFRydWU6CiAgICAgICAgYXVkaW8gPSB3b3JrX3F1ZXVlLmdldCgpCiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZWdtZW50cywgXyA9IG1vZGVsLnRyYW5zY3JpYmUoCiAgICAgICAgICAgICAgICBhdWRpbywKICAgICAgICAgICAgICAgIGxhbmd1YWdlPSJlbiIsCiAgICAgICAgICAgICAgICB2YWRfZmlsdGVyPVRydWUsCiAgICAgICAgICAgICAgICBiZWFtX3NpemU9MSwKICAgICAgICAgICAgICAgIGNvbmRpdGlvbl9vbl9wcmV2aW91c190ZXh0PUZhbHNlLAogICAgICAgICAgICApCiAgICAgICAgICAgIHRleHQgPSAiICIuam9pbihzLnRleHQuc3RyaXAoKSBmb3IgcyBpbiBzZWdtZW50cykuc3RyaXAoKQogICAgICAgICAgICBpZiBub3QgdGV4dDoKICAgICAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgICAgIHByaW50KGYiRU46IHt0ZXh0fSIpCiAgICAgICAgICAgIHByaW50KGYiQ1o6IHt0b19jemVjaCh0ZXh0KX1cbiIpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbiBhcyBleGM6CiAgICAgICAgICAgIHByaW50KGYiW2NoeWJhIHDFmWVwaXN1OiB7ZXhjfV0iKQogICAgICAgIGZpbmFsbHk6CiAgICAgICAgICAgIHdvcmtfcXVldWUudGFza19kb25lKCkKCgppZiBfX25hbWVfXyA9PSAiX19tYWluX18iOgogICAgdGhyZWFkaW5nLlRocmVhZCh0YXJnZXQ9dHJhbnNjcmliZXIsIGRhZW1vbj1UcnVlKS5zdGFydCgpCiAgICB0cnk6CiAgICAgICAgY2FwdHVyZSgpCiAgICBleGNlcHQgS2V5Ym9hcmRJbnRlcnJ1cHQ6CiAgICAgICAgcHJpbnQoIlxuS29uZWMuIikK'
    'requirements.txt' = 'UHlBdWRpb1dQYXRjaApmYXN0ZXItd2hpc3BlcgpudW1weQpzY2lweQpkZWVwbApudmlkaWEtY3VibGFzLWN1MTIKbnZpZGlhLWN1ZG5uLWN1MTIK'
    'run.ps1' = 'JGVudjpIRl9IVUJfRElTQUJMRV9YRVQgPSAiMSIKCiRrZXlGaWxlID0gSm9pbi1QYXRoICRQU1NjcmlwdFJvb3QgImRlZXBsX2tleS50eHQiCmlmIChUZXN0LVBhdGggJGtleUZpbGUpIHsKICAgICRlbnY6REVFUExfS0VZID0gKEdldC1Db250ZW50ICRrZXlGaWxlIC1SYXcpLlRyaW0oKQp9CgomICIkUFNTY3JpcHRSb290XC52ZW52XFNjcmlwdHNccHl0aG9uLmV4ZSIgIiRQU1NjcmlwdFJvb3RcbG9vcGJhY2tfdHJhbnNsYXRvci5weSIK'
    'start.bat' = 'QGVjaG8gb2ZmCnBvd2Vyc2hlbGwgLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJX5kcDBzdGFydF9oZWxwZXIucHMxIgplY2hvLgpwYXVzZQo='
}
foreach ($name in $files.Keys) {
    $bytes = [System.Convert]::FromBase64String($files[$name])
    [System.IO.File]::WriteAllBytes((Join-Path $targetDir $name), $bytes)
}
Write-Host "   OK" -ForegroundColor Green
Write-Host ""
$ErrorActionPreference = "Stop"

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Find-Python {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) {
        $ver = & python --version 2>&1
        if ($ver -match "Python 3\.(1[1-9]|[2-9]\d)") { return $cmd.Source }
    }
    return $null
}

Write-Host "=== Mumble do CZ - instalace (NVIDIA GPU) ===" -ForegroundColor Cyan
Write-Host ""

# 1) NVIDIA GPU
Write-Host "1) Kontrola NVIDIA graficke karty..."
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
if (-not $gpu) {
    Write-Host "   V PC nebyla nalezena NVIDIA graficka karta. Tento instalator je jen pro NVIDIA GPU verzi." -ForegroundColor Red
    try { Read-Host "Stiskni Enter pro konec" } catch {}
    exit 1
}
Write-Host "   OK: $($gpu.Name)" -ForegroundColor Green

# 2) Python
Write-Host ""
Write-Host "2) Kontrola Pythonu..."
$pythonExe = Find-Python
if (-not $pythonExe) {
    Write-Host "   Python nenalezen, instaluji pres winget (Python 3.13)..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "   winget neni k dispozici. Nainstaluj Python rucne z https://python.org a spust instalaci znovu." -ForegroundColor Red
        try { Read-Host "Stiskni Enter pro konec" } catch {}
        exit 1
    }
    winget install --id Python.Python.3.13 -e --source winget --accept-package-agreements --accept-source-agreements
    Refresh-Path
    $pythonExe = Find-Python
    if (-not $pythonExe) {
        Write-Host "   Python se nepodarilo najit ani po instalaci. Zavri toto okno, otevri nove PowerShell okno a spust install.bat znovu." -ForegroundColor Red
        try { Read-Host "Stiskni Enter pro konec" } catch {}
        exit 1
    }
}
Write-Host "   OK: $pythonExe" -ForegroundColor Green

# 3) venv
Write-Host ""
Write-Host "3) Virtualni prostredi (.venv)..."
$venvPython = Join-Path $targetDir ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    & $pythonExe -m venv (Join-Path $targetDir ".venv")
}
Write-Host "   OK" -ForegroundColor Green

# 4) balicky
Write-Host ""
Write-Host "4) Instalace balicku (muze chvili trvat, stahuji se i CUDA knihovny)..."
& $venvPython -m pip install --upgrade pip --quiet
& $venvPython -m pip install -r (Join-Path $targetDir "requirements.txt")
Write-Host "   OK" -ForegroundColor Green

# 5) over GPU
Write-Host ""
Write-Host "5) Overeni GPU..."
$cudaCount = & $venvPython -c "import ctranslate2; print(ctranslate2.get_cuda_device_count())" 2>$null
if ($cudaCount -match "^\d+$" -and [int]$cudaCount -ge 1) {
    Write-Host "   OK, GPU pripraveno ($cudaCount zarizeni)" -ForegroundColor Green
} else {
    Write-Host "   POZOR: GPU se nepodarilo overit, zkontroluj ovladace NVIDIA karty." -ForegroundColor Yellow
}

# 6) DeepL klic
Write-Host ""
$keyFile = Join-Path $targetDir "deepl_key.txt"
if (Test-Path $keyFile) {
    Write-Host "6) DeepL klic uz je nastaveny, preskakuji."
} else {
    Write-Host "6) DeepL API klic (volitelne - bez nej skript jen prepisuje anglicky, neprekada)."
    $key = $null
    try { $key = Read-Host "   Zadej DeepL API klic (nebo nech prazdne a stiskni Enter)" } catch { $key = $null }
    if ($key) {
        Set-Content -Path $keyFile -Value $key -NoNewline
        Write-Host "   Ulozeno." -ForegroundColor Green
    } else {
        Write-Host "   Preskoceno, muzes doplnit pozdeji do souboru deepl_key.txt." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Hotovo! ===" -ForegroundColor Cyan
Write-Host "Spusteni: start.bat"
Write-Host "Zastaveni: stop.bat"
try { Read-Host "Stiskni Enter pro konec" } catch {}

Write-Host "Slozka: $targetDir"

