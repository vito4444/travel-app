#!/usr/bin/env bash
# 在任何装有 Swift 工具链的机器（含 Linux）上验证解析器与路线优化算法的行为。
set -euo pipefail
cd "$(dirname "$0")"
swiftc -o /tmp/tripkeeper-verify \
  stubs.swift \
  ../TripKeeper/Services/BookingTextParser.swift \
  ../TripKeeper/Services/RouteOptimizer.swift \
  main.swift
/tmp/tripkeeper-verify
