function defaults() {
  return { enabled: false, dayStart: "07:00", nightStart: "21:00", dayProfile: "balanced", nightProfile: "power-saver" }
}

function minutes(time) {
  if (typeof time !== "string" || !/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(time)) return -1
  return Number(time.slice(0, 2)) * 60 + Number(time.slice(3))
}

function isProfile(profile) {
  return ["balanced", "performance", "power-saver"].indexOf(profile) !== -1
}

function valid(config) {
  return config && typeof config.enabled === "boolean"
    && minutes(config.dayStart) >= 0 && minutes(config.nightStart) >= 0
    && config.dayStart !== config.nightStart
    && isProfile(config.dayProfile) && isProfile(config.nightProfile)
}

function isDay(config, now) {
  var start = minutes(config.dayStart), end = minutes(config.nightStart)
  var minute = now.getHours() * 60 + now.getMinutes()
  return start < end ? minute >= start && minute < end : minute >= start || minute < end
}

function target(config, now) {
  return isDay(config, now) ? config.dayProfile : config.nightProfile
}

function nextTime(config, now) {
  return isDay(config, now) ? config.nightStart : config.dayStart
}
