import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';

void main() {
  test('igualdad por valor: mismo id y sección son iguales', () {
    // Arrange / Act / Assert
    expect(
      CatalogEntry(id: LevelId('l-1'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('l-1'), section: LevelSection.campaign),
    );
  });

  test('difiere cuando cambia la sección', () {
    // Arrange / Act / Assert
    expect(
      CatalogEntry(id: LevelId('l-1'), section: LevelSection.campaign),
      isNot(CatalogEntry(id: LevelId('l-1'), section: LevelSection.themed)),
    );
  });

  test('difiere cuando cambia el id', () {
    // Arrange / Act / Assert
    expect(
      CatalogEntry(id: LevelId('l-1'), section: LevelSection.themed),
      isNot(CatalogEntry(id: LevelId('l-2'), section: LevelSection.themed)),
    );
  });
}
