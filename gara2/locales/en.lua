local Translations = {
    error = {
        not_your_vehicle = 'Đây không phải xe của bạn.',
        no_free_spots = 'Không còn chỗ trống trong bãi đậu xe này.',
        not_in_vehicle = 'Bạn cần ở trong một phương tiện.',
        cannot_park = 'Không thể đậu xe.',
        not_parked_here = 'Đây không phải xe của bạn hoặc nó không được đậu ở đây.'
    },
    success = {
        vehicle_parked = 'Phương tiện của bạn đã được đậu.',
        vehicle_retrieved = 'Bạn đã lấy xe của mình.'
    },
    info = {
        blip_name = 'Bãi Đậu Xe Cá Nhân',
        park_prompt = '[E] - Đậu Xe',
        retrieve_prompt = 'Lấy Xe'
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})