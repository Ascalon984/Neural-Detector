import 'dart:convert';
import 'dart:io';

class WordpieceTokenizer {
  final Map<String, int> vocab;
  final String unkToken;
  final String clsToken;
  final String sepToken;
  final int maxLen;

  WordpieceTokenizer(this.vocab, {this.unkToken = '[UNK]', this.clsToken = '[CLS]', this.sepToken = '[SEP]', this.maxLen = 128});

  static Future<WordpieceTokenizer> fromVocabFile(String path, {int maxLen = 128}) async {
    final file = File(path);
    final lines = await file.readAsLines(encoding: utf8);
    final map = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      final tok = lines[i].trim();
      if (tok.isEmpty) continue;
      map[tok] = i;
    }
    return WordpieceTokenizer(map, maxLen: maxLen);
  }

  List<int> tokenizeToIds(String text) {
    // Simple whitespace tokenization then WordPiece greedy
    final words = text.split(RegExp(r"\s+"));
    final tokens = <String>[];
    for (final word in words) {
      final subtokens = _wordPieceTokenize(word);
      tokens.addAll(subtokens);
    }

    // Add special tokens CLS ... SEP optional depending on model
    final out = <int>[];
    if (vocab.containsKey('[CLS]')) out.add(vocab['[CLS]']!);
    for (final t in tokens) {
      out.add(vocab[t] ?? vocab[unkToken] ?? 0);
    }
    if (vocab.containsKey('[SEP]')) out.add(vocab['[SEP]']!);

    // pad/truncate
    if (out.length > maxLen) {
      return out.sublist(0, maxLen);
    }
    while (out.length < maxLen) out.add(0);
    return out;
  }

  List<int> attentionMaskFromIds(List<int> ids) {
    final mask = List<int>.filled(ids.length, 0);
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != 0) mask[i] = 1;
    }
    return mask;
  }

  List<String> _wordPieceTokenize(String word) {
    final subtokens = <String>[];
    var start = 0;
    final len = word.length;
    while (start < len) {
      var end = len;
      String cur = '';
      while (start < end) {
        var piece = word.substring(start, end);
        if (start > 0) piece = '##' + piece;
        if (vocab.containsKey(piece)) {
          cur = piece;
          break;
        }
        end -= 1;
      }
      if (cur == '') {
        // fallback to unk
        subtokens.add(unkToken);
        break;
      }
      subtokens.add(cur);
      start = end;
    }
    return subtokens;
  }
}
