## CardAudio — 卡片读音播放助手
##
## 用法：CardAudio.play_card_audio(card, self)
## 创建一个一次性 AudioStreamPlayer 挂在 parent 节点下，播放完后自动 queue_free。
## audio_path 为空或资源不存在时安静地返回（带 push_warning 提示），不会崩溃。
class_name CardAudio extends RefCounted


static func play_card_audio(card: Card, parent: Node) -> void:
	if card == null:
		return
	if card.audio_path == null or card.audio_path.is_empty():
		return
	if parent == null or not is_instance_valid(parent):
		return
	if not ResourceLoader.exists(card.audio_path):
		push_warning("Card audio missing: " + str(card.audio_path))
		return
	var stream: AudioStream = load(card.audio_path) as AudioStream
	if stream == null:
		push_warning("Card audio not an AudioStream: " + str(card.audio_path))
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
