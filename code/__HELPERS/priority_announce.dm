// please don't use these defines outside of this file in order to ensure a unified framework. unless you have a really good reason to make them global, then whatever

// these four are just text spans that furnish the TEXT itself with the appropriate CSS classes
#define MAJOR_ANNOUNCEMENT_TITLE(string) ("<span class='major_announcement_title'>" + string + "</span>")
#define SUBHEADER_ANNOUNCEMENT_TITLE(string) ("<span class='subheader_announcement_text'>" + string + "</span>")
#define MAJOR_ANNOUNCEMENT_TEXT(string) ("<span class='major_announcement_text'>" + string + "</span>")
#define MINOR_ANNOUNCEMENT_TITLE(string) ("<span class='minor_announcement_title'>" + string + "</span>")
#define MINOR_ANNOUNCEMENT_TEXT(string) ("<span class='minor_announcement_text'>" + string + "</span>")

#define ANNOUNCEMENT_HEADER(string) ("<span class='announcement_header'>" + string + "</span>")

// these two are the ones that actually give the striped background
#define CHAT_ALERT_DEFAULT_SPAN(string) ("<div class='chat_alert_default'>" + string + "</div>")
#define CHAT_ALERT_COLORED_SPAN(color, string) ("<div class='chat_alert_" + color + "'>" + string + "</div>")

#define ANNOUNCEMENT_COLORS list("default", "green", "blue", "pink", "yellow", "orange", "red", "purple")

/**
 * Buyuk kirmizi bir duyuru gosterir
 *
 * Format:
 *
 * " Mesaji Gonderen "
 *
 * " Baslik "
 *
 * " Yazi "
 *
 * Arguments
 * * text - gerekli, duyuru metni.
 * * title - opsiyonel, duyuru basligi.
 * * sound - opsiyonel, duyuru ile birlikte oynatilacak ses.
 * * type - opsiyonel, kullanilacak duyuru sablonlari. Bkz. __DEFINES/announcements.dm
 * * sender_override - opsiyonel, duyurunun gondericisini duzenler
 * * has_important_message - opsiyonel, bu mesaj istasyon icin kritik mi (istasyon traitlerini gecersiz kilsin mi), degil mi
 * * players - opsiyonel, mesajin gonderilecegi oyuncular listesi. varsayilan olarak tum oyuncular (yeni oyuncular dahil degildir)
 * * encode_title - opsiyonel, TRUE ise, duyuru basligi HTML kodlu olacaktir
 * * encode_text - opsiyonel, TRUE ise, duyuru metni HTML kodlu olacaktir
 */
/proc/priority_announce(text, title = "", sound, type, sender_override, has_important_message = FALSE, list/mob/players = GLOB.player_list, encode_title = TRUE, encode_text = TRUE, color_override)
	if(!text)
		return

	if(encode_title && title && length(title) > 0)
		title = html_encode(title)
	if(encode_text)
		text = html_encode(text)
		if(!length(text))
			return

	var/list/announcement_strings = list()

	if(!sound)
		sound = SSstation.announcer.get_rand_alert_sound()
	else if(SSstation.announcer.event_sounds[sound])
		sound = SSstation.announcer.event_sounds[sound]

	var/header
	switch(type)
		if(ANNOUNCEMENT_TYPE_PRIORITY)
			header = MAJOR_ANNOUNCEMENT_TITLE("Öncelik Duyurusu")
			if(length(title) > 0)
				header += SUBHEADER_ANNOUNCEMENT_TITLE(title)
		if(ANNOUNCEMENT_TYPE_CAPTAIN)
			header = MAJOR_ANNOUNCEMENT_TITLE("Kaptanın Duyurusu")
			GLOB.news_network.submit_article(text, "Kaptanın Duyurusu", "İstasyon Duyuruları", null)
		if(ANNOUNCEMENT_TYPE_SYNDICATE)
			header = MAJOR_ANNOUNCEMENT_TITLE("Sendika Kaptanının Duyurusu")
		else
			header += generate_unique_announcement_header(title, sender_override)

	announcement_strings += ANNOUNCEMENT_HEADER(header)

	///If the announcer overrides alert messages, use that message.
	if(SSstation.announcer.custom_alert_message && !has_important_message)
		announcement_strings += MAJOR_ANNOUNCEMENT_TEXT(SSstation.announcer.custom_alert_message)
	else
		announcement_strings += MAJOR_ANNOUNCEMENT_TEXT(text)

	var/finalized_announcement
	if(color_override)
		finalized_announcement = CHAT_ALERT_COLORED_SPAN(color_override, jointext(announcement_strings, ""))
	else
		finalized_announcement = CHAT_ALERT_DEFAULT_SPAN(jointext(announcement_strings, ""))

	dispatch_announcement_to_players(finalized_announcement, players, sound)

	if(isnull(sender_override) && players == GLOB.player_list)
		if(length(title) > 0)
			GLOB.news_network.submit_article(title + "<br><br>" + text, "[command_name()]", "İstasyon Duyuruları", null)
		else
			GLOB.news_network.submit_article(text, "[command_name()] Bildirisi", "İstasyon Duyuruları", null)

/proc/print_command_report(text = "", title = null, announce=TRUE)
	if(!title)
		title = "Gizli [command_name()] Bildirisi"

	if(announce)
		priority_announce(
			text = "Bir rapor indirildi ve tüm iletişim konsollarından yazdırıldı.",
			title = "Gelen Gizli Mesaj",
			sound = SSstation.announcer.get_rand_report_sound(),
			has_important_message = TRUE,
		)

	var/datum/comm_message/message = new
	message.title = title
	message.content = text

	SScommunications.send_message(message)

/**
 * Sends a minor annoucement to players.
 * Minor announcements are large text, with the title in red and message in white.
 * Only mobs that can hear can see the announcements.
 *
 * message - the message contents of the announcement.
 * title - the title of the announcement, which is often "who sent it".
 * alert - whether this announcement is an alert, or just a notice. Only changes the sound that is played by default.
 * html_encode - if TRUE, we will html encode our title and message before sending it, to prevent player input abuse.
 * players - optional, a list mobs to send the announcement to. If unset, sends to all palyers.
 * sound_override - optional, use the passed sound file instead of the default notice sounds.
 * should_play_sound - Whether the notice sound should be played or not.
 * color_override - optional, use the passed color instead of the default notice color.
 */
/proc/minor_announce(message, title = "Dikkat:", alert = FALSE, html_encode = TRUE, list/players, sound_override, should_play_sound = TRUE, color_override)
	if(!message)
		return

	if (html_encode)
		title = html_encode(title)
		message = html_encode(message)

	var/list/minor_announcement_strings = list()
	if(title != null && title != "")
		minor_announcement_strings += ANNOUNCEMENT_HEADER(MINOR_ANNOUNCEMENT_TITLE(title))
	minor_announcement_strings += MINOR_ANNOUNCEMENT_TEXT(message)

	var/finalized_announcement
	if(color_override)
		finalized_announcement = CHAT_ALERT_COLORED_SPAN(color_override, jointext(minor_announcement_strings, ""))
	else
		finalized_announcement = CHAT_ALERT_DEFAULT_SPAN(jointext(minor_announcement_strings, ""))

	var/custom_sound = sound_override || (alert ? 'sound/misc/notice1.ogg' : 'sound/misc/notice2.ogg')
	dispatch_announcement_to_players(finalized_announcement, players, custom_sound, should_play_sound)

/// Sends an announcement about the level changing to players. Uses the passed in datum and the subsystem's previous security level to generate the message.
/proc/level_announce(datum/security_level/selected_level, previous_level_number)
	var/current_level_number = selected_level.number_level
	var/current_level_name = selected_level.name
	var/current_level_color = selected_level.announcement_color
	var/current_level_sound = selected_level.sound

	var/title
	var/message

	if(current_level_number > previous_level_number)
		title = "Dikkat! Güvenlik derecesi [current_level_name] seviyesine arttırıldı."
		message = selected_level.elevating_to_announcement
	else
		title = "Dikkat! Güvenlik derecesi [current_level_name] seviyesine düşürüldü."
		message = selected_level.lowering_to_announcement

	var/list/level_announcement_strings = list()
	level_announcement_strings += ANNOUNCEMENT_HEADER(MINOR_ANNOUNCEMENT_TITLE(title))
	level_announcement_strings += MINOR_ANNOUNCEMENT_TEXT(message)

	var/finalized_announcement = CHAT_ALERT_COLORED_SPAN(current_level_color, jointext(level_announcement_strings, ""))

	dispatch_announcement_to_players(finalized_announcement, GLOB.player_list, current_level_sound)

/// Proc that just generates a custom header based on variables fed into `priority_announce()`
/// Will return a string.
/proc/generate_unique_announcement_header(title, sender_override)
	var/list/returnable_strings = list()
	if(isnull(sender_override))
		returnable_strings += MAJOR_ANNOUNCEMENT_TITLE("[command_name()] Bildirisi")
	else
		returnable_strings += MAJOR_ANNOUNCEMENT_TITLE(sender_override)

	if(length(title) > 0)
		returnable_strings += SUBHEADER_ANNOUNCEMENT_TITLE(title)

	return jointext(returnable_strings, "")

/// Proc that just dispatches the announcement to our applicable audience. Only the announcement is a mandatory arg.
/proc/dispatch_announcement_to_players(announcement, list/players = GLOB.player_list, sound_override = null, should_play_sound = TRUE)
	var/sound_to_play = !isnull(sound_override) ? sound_override : 'sound/misc/notice2.ogg'

	for(var/mob/target in players)
		if(isnewplayer(target) || !target.can_hear())
			continue

		to_chat(target, announcement)
		if(!should_play_sound)
			continue

		if(target.client?.prefs.read_preference(/datum/preference/toggle/sound_announcements))
			SEND_SOUND(target, sound(sound_to_play))

#undef MAJOR_ANNOUNCEMENT_TITLE
#undef MAJOR_ANNOUNCEMENT_TEXT
#undef MINOR_ANNOUNCEMENT_TITLE
#undef MINOR_ANNOUNCEMENT_TEXT
#undef CHAT_ALERT_DEFAULT_SPAN
#undef CHAT_ALERT_COLORED_SPAN
