using KiwiKorean, Test

@testset "KiwiKorean" begin
    s = "😀 안녕하세요. 오늘 날씨가 좋네요!"

    @testset "형태소 분석" begin
        @test ("날씨", "NNG") in pos(s)
        @test ("가", "JKS") in pos(s)
        @test morphs("날씨가 좋다") == ["날씨", "가", "좋", "다"]
        @test nouns(s) == ["안녕", "오늘", "날씨"]
        @test morphs(s; tags=("VA", "NN")) == ["안녕", "오늘", "날씨", "좋"]
        @test tokenize("") == Token[]
        @test split_sentences(s) == ["😀 안녕하세요.", "오늘 날씨가 좋네요!"]
        @test space("아버지가방에들어가신다") == "아버지가 방에 들어가신다"
    end

    @testset "형태소 위치" begin
        t = "😀 걸어서 학교에 갔다"
        toks = tokenize(t)
        # Slicing the source text gives the surface form (the emoji is a UTF-16 surrogate pair, which exercises offset conversion).
        # 원문 슬라이스가 표층형과 일치 (이모지는 UTF-16 서로게이트 쌍이라 오프셋 변환 검증)
        @test [t[x.span] for x in toks] == ["😀", "걸", "어서", "학교", "에", "갔", "갔", "다"]
        @test toks[2] == Token("걷", "VV-I", toks[2].span)
    end

    @testset "용언 기본형" begin
        @test morphs("날씨가 좋네요"; lemma=true) == ["날씨", "가", "좋다", "네요"]
        @test morphs("걸어서 갔다"; tags=("VV",), lemma=true) == ["걷다", "가다"]
        @test ("학생", "NNG") in pos("그는 학생이다"; lemma=true)
        @test ("이다", "VCP") in pos("그는 학생이다"; lemma=true)
    end

    @testset "사용자 사전" begin
        word = "뉴진스님"
        @test !(word in nouns(word))
        k = Kiwi(user_words=[word => "NNP"])
        @test nouns(k, word) == [word]
        @test_throws ErrorException Kiwi(model="/없는/경로")
    end

    @testset "오타 교정" begin
        x = "맛있지 않았던것 가태"
        @test !(("같", "VA") in pos(x))
        k = Kiwi(typos=:basic_continual_lengthening)
        @test ("같", "VA") in pos(k, x)
        @test_throws ArgumentError Kiwi(typos=:없음)
    end

    @testset "신조어 추출" begin
        pre = ["요즘", "어제", "친구가 본", "유튜브에서", "갑자기", "오늘", "다들", "역시"]
        par = ["이", "을", "은", "도", "과", "의", "에게", "처럼"]
        post = ["유행이다", "좋아한다", "봤다", "대단하다", "웃기다", "따라했다"]
        texts = ["$a 뉴진스님$b $c" for a in pre for b in par for c in post]
        # This artificial corpus always has a space before words, so the branching-entropy score is 0; hence min_score=0.
        # 이 인위적 말뭉치는 단어 앞이 항상 공백이라 분기 엔트로피 점수가 0이 되므로 min_score=0
        w = extract_words([texts; ""]; min_score=0)
        hit = only(filter(x -> x.form == "뉴진스님", w))
        @test hit.freq == length(texts)
    end

    @testset "TextAnalysis.jl 연동" begin
        using TextAnalysis
        texts = ["오늘 날씨가 좋다", "날씨가 흐리다", "오늘 학교에 갔다"]
        crps = Corpus([TokenDocument(nouns(t)) for t in texts])
        update_lexicon!(crps)
        m = DocumentTermMatrix(crps)
        @test sort(m.terms) == sort(["오늘", "날씨", "학교"])
        d = dtm(m, :dense)
        col(w) = d[:, findfirst(==(w), m.terms)]
        @test col("날씨") == [1, 1, 0]
        @test col("학교") == [0, 0, 1]
        @test size(tf_idf(m)) == (3, 3)
        # Documents can also be built from lemmas instead of surface forms.
        # 표층형 대신 기본형으로 문서를 만들 수도 있다
        doc = TokenDocument(morphs("걸어서 갔다"; tags=("VV",), lemma=true))
        @test tokens(doc) == ["걷다", "가다"]
    end
end
