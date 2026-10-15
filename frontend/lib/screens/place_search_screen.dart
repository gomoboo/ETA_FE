import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String name;
  final String address;

  // 나중에 지도에서 약속 장소 좌표로 사용
  final double latitude;
  final double longitude;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() =>
      _PlaceSearchScreenState();
}

class _PlaceSearchScreenState
    extends State<PlaceSearchScreen> {
  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _blue = Color(0xFF1685B5);
  static const Color _gray = Color(0xFF7D919F);
  static const Color _border = Color(0xFFD7E5EC);

  // 카카오 REST API 키
  static const String _kakaoRestApiKey =
      String.fromEnvironment(
    'KAKAO_REST_API_KEY',
  );

  final TextEditingController _searchController =
      TextEditingController();

  List<PlaceResult> _places = [];

  bool _isLoading = false;
  bool _hasSearched = false;

  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===============================================================
  // 카카오 장소 검색
  // ===============================================================

  Future<void> _searchPlaces() async {
    final keyword =
        _searchController.text.trim();

    if (keyword.isEmpty) {
      return;
    }

    if (_kakaoRestApiKey.isEmpty) {
      setState(() {
        _errorMessage =
            'KAKAO_REST_API_KEY가 설정되지 않았어요.';
        _hasSearched = true;
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final uri = Uri.https(
        'dapi.kakao.com',
        '/v2/local/search/keyword.json',
        {
          'query': keyword,
          'size': '15',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization':
              'KakaoAK $_kakaoRestApiKey',
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
          _places = [];
          _errorMessage =
              '장소 검색에 실패했어요. (${response.statusCode})';
        });

        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final List<dynamic> documents =
          data['documents'] ?? [];

      final results =
          documents.map<PlaceResult>((document) {
        final roadAddress =
            (document['road_address_name'] ?? '')
                .toString();

        final address =
            roadAddress.isNotEmpty
                ? roadAddress
                : (document['address_name'] ?? '')
                    .toString();

        return PlaceResult(
          name:
              (document['place_name'] ?? '')
                  .toString(),
          address: address,
          latitude: double.tryParse(
                (document['y'] ?? '').toString(),
              ) ??
              0.0,
          longitude: double.tryParse(
                (document['x'] ?? '').toString(),
              ) ??
              0.0,
        );
      }).toList();

      setState(() {
        _places = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _places = [];
        _errorMessage =
            '장소를 검색하는 중 문제가 발생했어요.';
      });
    }
  }

  // ===============================================================
  // 화면
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            // =========================================================
            // 헤더
            // =========================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                24,
                22,
                24,
                12,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    borderRadius:
                        BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons
                            .arrow_back_ios_new_rounded,
                        size: 18,
                        color: _blue,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Text(
                    '장소 검색',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  22,
                  24,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =================================================
                    // 검색창
                    // =================================================

                    TextField(
                      controller:
                          _searchController,

                      autofocus: true,

                      textInputAction:
                          TextInputAction.search,

                      onSubmitted: (_) {
                        _searchPlaces();
                      },

                      onChanged: (_) {
                        setState(() {});
                      },

                      style:
                          const TextStyle(
                        fontSize: 13,
                        color: _navy,
                      ),

                      decoration:
                          InputDecoration(
                        hintText:
                            '장소를 검색해보세요',

                        hintStyle:
                            const TextStyle(
                          fontSize: 13,
                          color: _gray,
                        ),

                        prefixIcon:
                            const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: _gray,
                        ),

                        suffixIcon:
                            _searchController
                                    .text
                                    .isEmpty
                                ? null
                                : IconButton(
                                    onPressed:
                                        () {
                                      _searchController
                                          .clear();

                                      setState(() {
                                        _places =
                                            [];
                                        _hasSearched =
                                            false;
                                        _errorMessage =
                                            null;
                                      });
                                    },
                                    icon:
                                        const Icon(
                                      Icons
                                          .close_rounded,
                                      size: 20,
                                      color: _gray,
                                    ),
                                  ),

                        filled: true,
                        fillColor:
                            Colors.white,

                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          borderSide:
                              const BorderSide(
                            color: _border,
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          borderSide:
                              const BorderSide(
                            color: _blue,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      '검색 결과',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color: _navy,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =================================================
                    // 검색 중
                    // =================================================

                    if (_isLoading)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 30,
                        ),
                        child: Center(
                          child:
                              CircularProgressIndicator(
                            color: _blue,
                          ),
                        ),
                      )

                    // =================================================
                    // 오류
                    // =================================================

                    else if (_errorMessage != null)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 24,
                        ),
                        child: Center(
                          child: Text(
                            _errorMessage!,
                            style:
                                const TextStyle(
                              fontSize: 12,
                              color: _gray,
                            ),
                          ),
                        ),
                      )

                    // =================================================
                    // 검색했지만 결과 없음
                    // =================================================

                    else if (_hasSearched &&
                        _places.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 24,
                        ),
                        child: Center(
                          child: Text(
                            '검색 결과가 없어요.',
                            style:
                                TextStyle(
                              fontSize: 12,
                              color: _gray,
                            ),
                          ),
                        ),
                      )

                    // =================================================
                    // 실제 장소 검색 결과
                    // =================================================

                    else
                      ..._places.map(
                        (place) => Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 10,
                          ),
                          child:
                              _placeCard(
                            place,
                          ),
                        ),
                      ),

                    if (_places.isNotEmpty) ...[
                      const SizedBox(
                        height: 22,
                      ),

                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        child: Text(
                          '원하는 장소를 선택하면 약속 만들기 화면으로 돌아가요.',
                          style:
                              TextStyle(
                            fontSize: 11,
                            color: _gray,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // 장소 검색 결과 카드
  // ===============================================================

  Widget _placeCard(
    PlaceResult place,
  ) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(
          place,
        );
      },
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: _border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                      color: _navy,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    place.address,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            const Icon(
              Icons.location_on_outlined,
              size: 21,
              color: _blue,
            ),
          ],
        ),
      ),
    );
  }
}