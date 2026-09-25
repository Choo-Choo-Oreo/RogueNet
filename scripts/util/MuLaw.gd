class_name MuLaw
extends RefCounted

## G.711 mu-law: 16-bit samples squeezed into one byte each, finer steps for quiet sounds than
## loud ones (how phones send speech). Half the bytes of 16-bit PCM and cheap to do, so voice
## chat (VoiceChat) sends its mic chunks this way. Lossy, but speech stays clear.

const BIAS := 0x84
const CLIP := 32635

static var _decoded := PackedInt32Array()

## 16-bit little-endian PCM -> one byte per sample.
static func encode(pcm: PackedByteArray) -> PackedByteArray:
	@warning_ignore("integer_division")  # 2 bytes per sample
	var count := pcm.size() / 2
	var out := PackedByteArray()
	out.resize(count)
	for i in count:
		var sample := pcm.decode_s16(i * 2)
		var negative := 0x80 if sample < 0 else 0
		var magnitude := mini(absi(sample), CLIP) + BIAS
		var exponent := 7
		var mask := 0x4000
		while exponent > 0 and (magnitude & mask) == 0:
			exponent -= 1
			mask >>= 1
		var mantissa := (magnitude >> (exponent + 3)) & 0x0F
		out[i] = ~(negative | (exponent << 4) | mantissa) & 0xFF
	return out

## The other way: one byte per sample -> 16-bit little-endian PCM.
static func decode(data: PackedByteArray) -> PackedByteArray:
	if _decoded.is_empty():
		_decoded.resize(256)
		for byte in 256:
			var b := ~byte & 0xFF
			var magnitude := ((((b & 0x0F) << 3) + BIAS) << ((b >> 4) & 7)) - BIAS
			_decoded[byte] = -magnitude if (b & 0x80) != 0 else magnitude
	var pcm := PackedByteArray()
	pcm.resize(data.size() * 2)
	for i in data.size():
		pcm.encode_s16(i * 2, _decoded[data[i]])
	return pcm
