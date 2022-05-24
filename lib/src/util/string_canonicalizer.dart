// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

class Node {
  Node(this.data, this.start, this.end, this.payload, this.next);
  dynamic /* String | List<int> */ data;
  int start;
  int end;
  String payload;
  Node? next;
}

/// A hash table for triples:
/// (list of bytes, start, end) --> canonicalized string
/// Using triples avoids allocating string slices before checking if they
/// are canonical.
///
/// Gives about 3% speedup on dart2js.
class StringCanonicalizer {
  /// Mask away top bits to keep hash calculation within 32-bit SMI range.
  static const int mask = 16 * 1024 * 1024 - 1;

  static const int initialSize = 8 * 1024;

  /// Linear size of a hash table.
  int _size = initialSize;

  /// Items in a hash table.
  int _count = 0;

  /// The table itself.
  List<Node?> _nodes = List<Node?>.filled(initialSize, /* fill = */ null);

  static String decode(List<int> data, int start, int end, bool asciiOnly) {
    String s;
    if (asciiOnly) {
      s = String.fromCharCodes(data, start, end);
    } else {
      s = const Utf8Decoder(allowMalformed: true).convert(data, start, end);
    }
    return s;
  }

  static int hashBytes(List<int> data, int start, int end) {
    int h = 5381;
    for (int i = start; i < end; i++) {
      h = ((h << 5) + h + data[i]) & mask;
    }
    return h;
  }

  static int hashString(String data, int start, int end) {
    int h = 5381;
    for (int i = start; i < end; i++) {
      h = ((h << 5) + h + data.codeUnitAt(i)) & mask;
    }
    return h;
  }

  void rehash() {
    int newSize = _size * 2;
    List<Node?> newNodes = List<Node?>.filled(newSize, /* fill = */ null);
    for (int i = 0; i < _size; i++) {
      Node? t = _nodes[i];
      while (t != null) {
        Node? n = t.next;
        int newIndex = t.data is String
            ? hashString(t.data, t.start, t.end) & (newSize - 1)
            : hashBytes(t.data, t.start, t.end) & (newSize - 1);
        Node? s = newNodes[newIndex];
        t.next = s;
        newNodes[newIndex] = t;
        t = n;
      }
    }
    _size = newSize;
    _nodes = newNodes;
  }

  String canonicalize(data, int start, int end, bool asciiOnly) {
    if (_count > _size) rehash();
    int index = data is String
        ? hashString(data, start, end)
        : hashBytes(data, start, end);
    index = index & (_size - 1);
    Node? s = _nodes[index];
    Node? t = s;
    int len = end - start;
    while (t != null) {
      if (t.end - t.start == len) {
        int i = start, j = t.start;
        while (i < end && data[i] == t.data[j]) {
          i++;
          j++;
        }
        if (i == end) {
          return t.payload;
        }
      }
      t = t.next;
    }
    String payload;
    if (data is String) {
      payload = data.substring(start, end);
    } else {
      payload = decode(data, start, end, asciiOnly);
    }
    _nodes[index] = Node(data, start, end, payload, s);
    _count++;
    return payload;
  }

  void clear() {
    _size = initialSize;
    _nodes = List<Node?>.filled(_size, /* fill = */ null);
    _count = 0;
  }
}
