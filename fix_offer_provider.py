import os

file_path = 'lib/providers/offer_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix list method
content = content.replace(
'''      final list = data['offers'] as List;
      final list = (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();''',
'''      final rawList = data['offers'] as List;
      final list = rawList
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();'''
)

# Fix get by id method
content = content.replace(
'''      final offerData = data['offer'];
      if (offerData == null) return null;
      if (response == null || (response as List).isEmpty) return null;
      final row = Map<String, dynamic>.from(response.first as Map);
      final offer = OfferModel.fromSupabase(row, row['id'] as String);''',
'''      final offerData = data['offer'];
      if (offerData == null) return null;
      final row = Map<String, dynamic>.from(offerData as Map);
      final offer = OfferModel.fromSupabase(row, row['id'] as String);'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

