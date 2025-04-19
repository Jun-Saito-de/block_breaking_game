import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart'; // PositionComponent などFlameの主要なコンポーネントを使うため
import 'package:flame/collisions.dart'; // 衝突判定に必要
import 'package:flutter/services.dart'; // キーボードイベントに必要
import 'package:flame/input.dart'; // キーボード入力対応のKeyboardhandlerを使うため

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Break Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 255, 199, 45),
        ),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text('ブロック崩し'),
      ),
      body: GameWidget(game: BlockBreakerGame()),
    );
  }
}

// HasKeyboardHandlerComponents = ゲーム全体がキーボード入力を監視し、キーイベントをコンポーネント（BarSprite）に渡せるようにするための仕組み
class BlockBreakerGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  // ブロックの数をゲーム側で管理するようにする
  final List<BlockSprite> blocks = [];

  @override
  Color backgroundColor() => const Color.fromARGB(255, 19, 2, 40);

  // 5.BarSpriteを追加してバーを画面表示
  @override
  Future<void> onLoad() async {
    // TODO: implement onLoad
    await super.onLoad();
    add(BarSprite());
    // 7.作成したBallSpriteを追加してボールを表示
    add(BallSprite());
    // 9. 壁と跳ね返るように設定
    add(ScreenHitbox());

    // 10-2. ブロックをゲーム画面に表示
    // ブロックのサイズはゲーム画面幅-60px(少し余裕を持たせるため) ÷5（横に５本並べるため）
    final blockSize = Vector2((size.x - 60) / 5, 20);

    // 各行に適用するブロックの色を規定
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.cyan,
      Colors.blue,
      Colors.purple,
    ];

    // 色ごとに行を作る（縦に7行）
    for (int row = 0; row < colors.length; row++) {
      // 横に5個ずつ並べる
      for (int col = 0; col < 5; col++) {
        final pos = Vector2(
          col * (blockSize.x + 10) + 10, // 横位置：間隔10px
          row * 30 + 50, // 縦位置：30px間隔、50px下から開始
        );

        // ブロック追加 （さきほど規定した定数をBlockSpriteの引数とする）
        // add(BlockSprite(blockSize, pos, colors[row]));

        // ブロック生成時に blocks に登録
        final block = BlockSprite(blockSize, pos, colors[row]);
        add(block);
        blocks.add(block);
      }
    }
  }
}

// 4.画面下のバーのクラスを作成
// PositionComponent =「画面上に配置できる要素」（位置やサイズを持つ）を表す基本のコンポーネント
// バーのボールとの衝突判定を扱うための　with CollisionCallbacks
// バーはキーボードのキーで動かすので with KeyboardHandler
// gameRef という変数で、自分が所属するゲームクラス（BlockBreakerGame）にアクセス →  with HasGameRef
class BarSprite extends PositionComponent
    with CollisionCallbacks, KeyboardHandler, HasGameRef {
  // バーの移動量ベクトル（初期は0）
  Vector2 _delta = Vector2.zero(); // .zero() = (x=0, y=0)
  late Paint _paint; // バーの色など描画用の設定
  BarSprite();

  // onLoadメソッドの中でバーの位置・サイズ・色などを初期化
  // Flameでは onLoad() の中で 初期設定（位置・サイズ・色など） を行う
  @override
  Future<void> onLoad() async {
    await super.onLoad(); // 親クラス側の初期処理もきちんと実行

    // バーのサイズを設定
    size = Vector2(100, 25); // 横100px/縦25px
    // バーの位置を決定
    // 横幅いっぱい / 2 →  画面中央にバーの左端がくる →  バーの中央を中央に持っていきたいため、マイナス50（バーの横幅の50%）
    // 縦幅いっぱい（画面最下）の値 -50 →  下が25px空いたところにバーがくる
    position = Vector2(gameRef.size.x / 2 - 50, gameRef.size.y - 50);
    // バーの色を決定（paintが必要）
    _paint =
        Paint()
          // カスケード演算子で表記（変数名を書き直す手間を省く）
          ..style =
              PaintingStyle
                  .fill // = _paint.style = PaintingStyle.fill;
          ..color = Colors.white; // = _paint.color = Colors.white;

    // バーに衝突を判定するHitboxを追加
    add(RectangleHitbox()); // RectangleHitbox →  バーの形に合わせたヒットボックス
  }

  // → 親クラス（PositionComponent）が持つ render() を**上書き（カスタマイズ）**
  @override
  void render(Canvas canvas) {
    // Flameが自動的に呼び出す「描画用メソッド」です！ canvas というのは描画先のキャンバスです（お絵かきボードみたいなもの🎨）
    super.render(
      canvas,
    ); // 必ず最初に呼びましょう！親クラス側で必要な描画処理をやってくれます ※@overriderenderの変換で一緒に出てくる

    final r = Rect.fromLTWH(
      0,
      0,
      size.x,
      size.y,
    ); // （左から0、上からゼロ、左からxの長さ、上からyの長さ）= バーのサイズ通りの長方形を、(0, 0)基準で描く
    canvas.drawRect(r, _paint); // 作った Rect を、_paint の色（白）でキャンバスに描きます
  }

  // update() でバーを 移動させる処理を行う
  @override
  void update(double dt) {
    // 毎フレーム呼び出されるFlameの処理
    super.update(dt);
    // 移動予定位置を計算
    final nextPosition = position + _delta * dt * 100; // 滑らかに移動

    // 左端 >= 0、右端 <= 画面サイズ の範囲に収まるように
    if (nextPosition.x >= 0 && nextPosition.x + size.x <= gameRef.size.x) {
      position = nextPosition;
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // TODO: implement onKeyEvent
    if (event is KeyUpEvent) {
      _delta = Vector2.zero(); // キーを離したら移動量ゼロ＝止まる
    }
    if (event.character == "j") {
      _delta.x = -3; // 左に3pxずつ進む
    }
    if (event.character == "l") {
      _delta.x = 3; // 右に3pxずつ進む
    }
    return true;
  }
}

// ボールのクラスを作成
class BallSprite extends CircleComponent
    with HasGameRef<BlockBreakerGame>, CollisionCallbacks {
  // with HasGameRef<BlockBreakerGame> →  ゲーム画面のサイズにアクセスするため
  // 9.　CollisionCallbacks 衝突検知
  final double _size = 25.0; // ボールの直径を25pxに設定
  late Vector2 _velocity; // 移動方向とスピードをまとめたベクトル。今後ボールのベクトルは_velocityをもとに調整する

  // 9-2. ゲームオーバーフラグは一度だけ表示されるようにする
  bool _isGameOver = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    size = Vector2(_size, _size); // 円の大きさを設定（正円）
    position = Vector2(
      gameRef.size.x / 2 - _size / 2, //左右の中央に位置
      gameRef.size.y - 100, // 画面最下から100px上の位置
    );

    paint = Paint()..color = Colors.white; // ボールを白に塗る
    _velocity = Vector2(1, -1); // 右上に向かう移動方向のベクトル

    add(CircleHitbox()); // 9. 衝突判定のヒットボックス追加
  }

  // ボールに移動処理を追加
  @override
  void update(double dt) {
    super.update(dt);

    position += _velocity * dt * 100;
  }

  // ボールに、壁（画面端）への跳ね返りを追加
  @override
  void onCollision(Set<Vector2> points, PositionComponent other) {
    super.onCollision(points, other);

    // 跳ね返り条件を指定
    // 位置が0以下（画面左壁に接触）ならプラスの方向（右向き）に
    if (position.x <= 0) {
      _velocity.x = _velocity.x.abs();
    }
    // 位置がサイズ画面以上（画面右壁に接触）ならマイナスの方向（左向き）に
    if (position.x >= gameRef.size.x - size.x) {
      _velocity.x = -_velocity.x.abs();
    }
    // 位置がサイズ画面最上（画面上壁に接触）ならyをプラスの方向（下向き）に
    if (position.y <= 0) {
      _velocity.y = _velocity.y.abs();
    }
    // 位置がサイズ画面以上（画面最下に接触）なら動きを止めてゲームオーバーと出力
    // if (position.y >= gameRef.size.y - size.y) {
    //   _velocity = Vector2.zero();  // _velocity = Vector2.zero();  →  Vector2.zero()は移動量ゼロ＝止まる
    //   print("GAME OVER");
    // }
    // 9-2. 変更。フラグ変数 _isGameOver を導入することで最初の1回だけ GAME OVER が出る。その後はもう条件に入らない
    if (!_isGameOver && position.y >= gameRef.size.y - size.y) {
      _velocity = Vector2.zero();
      _isGameOver = true; // フラグONにして、もう反応しないようにする
      // 12-2, ゲームポーバーのテキスト表示
      gameRef.add(
        TextComponent(
          text: 'GAME OVER',
          position: gameRef.size / 2,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              fontSize: 48,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // バーとボールの跳ね返り
    if (other is BarSprite) {
      // otherとは、ボールが衝突した相手のコンポーネントのこと (衝突の相手がバーなら)
      _velocity.y = -_velocity.y.abs(); // バーに当たったらマイナス方向（上方向）へ

      // バーの中心とボールの位置の差によって、X方向を少し調整する
      // バーの中心位置：100pxのところに位置していた場合、100pxにバーの横幅の半分を足した位置がバーの中心になる
      final barCenter = other.position.x + other.size.x / 2;
      // ボールがもし100pxの位置なら、100pxにボールの横幅の半分を足した位置がボールの中心になる
      final ballCenter = position.x + size.x / 2;
      // offset = ボールの中心 - バーの中心
      final offset = (ballCenter - barCenter) / 20;
      _velocity.x += offset;
    }

    // 11. ブロックとぶつかったらボールの向きを変更（跳ね返り）
    if (other is BlockSprite) {
      if (position.x + size.x / 2 < other.position.x) {
        _velocity.x = -_velocity.x.abs();
      }
      if (position.x + size.x / 2 > other.position.x) {
        _velocity.x = _velocity.x.abs();
      }
      if (position.y + size.y / 2 < other.position.y) {
        _velocity.y = -_velocity.y.abs();
      }
      if (position.y + size.y / 2 > other.position.y) {
        _velocity.y = _velocity.y.abs();
      }

      gameRef.blocks.remove(other);
      //11-2. ✅ 衝突したブロックを削除（←これを追加！）
      other.removeFromParent();
      if (gameRef.blocks.isEmpty) {
        _velocity = Vector2.zero();
        gameRef.add(
          TextComponent(
            text: 'YOU WIN!',
            position: gameRef.size / 2,
            anchor: Anchor.center,
            textRenderer: TextPaint(
              style: TextStyle(
                fontSize: 48,
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }
  }
}

// 10. ブロック用のblockSpriteクラスを作成
// BlockSpriteクラスはPositionComponentを継承
// with CollisionCallbacks, HasGameRef<BlockBreakerGame>で衝突判定やゲームの機能が使えるようにする
class BlockSprite extends PositionComponent
    with CollisionCallbacks, HasGameRef<BlockBreakerGame> {
  // ブロックのサイズ定義
  final Vector2 _size;
  final Vector2 _position;
  final Color _color;
  late Paint _paint; // Paint() は onLoad() の中で初期化するから、コンストラクタではまだ値が決まっていない

  // 「ブロックの見た目・位置・色の設定を、SampleGame（BlockBreakerGame） 側から渡して受け取る」
  BlockSprite(this._size, this._position, this._color);

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    size = _size;
    position = _position;
    // ブロックの色を決定（paintが必要）
    _paint =
        Paint()
          // カスケード演算子で表記（変数名を書き直す手間を省く）
          ..style =
              PaintingStyle
                  .fill // = _paint.style = PaintingStyle.fill;
          ..color = _color; // = _paint.color = _color;
    add(RectangleHitbox()); // 長方形のボックス（ブロック）を追加
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final r = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(r, _paint);
  }
}
