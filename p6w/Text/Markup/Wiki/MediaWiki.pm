use v6;

grammar Tokenizer {
    regex TOP { ^ <token>* $ }
    regex token { <bold_marker> | <italic_marker> | <plain> }
    regex bold_marker { '&#039;&#039;&#039;' }
    regex italic_marker { '&#039;&#039;' }
    regex plain { [<!before '&#039;&#039;'> .]+ }
}

class Text::Markup::Wiki::MediaWiki {

    sub entities(*@words) {
        return map { "&$_;" }, @words.values;
    }

    sub merge_consecutive_paragraphs(*@parlist) {
        for 0 ..^ @parlist.elems-1 -> $ix {
            if @parlist[$ix] ~~ /^'<p>'/ && @parlist[$ix+1] ~~ /^'<p>'/ {
                @parlist[$ix+1] = @parlist[$ix] ~ @parlist[$ix+1];
                @parlist[$ix+1] .= subst( '</p><p>', ' ' );

                @parlist[$ix] = undef;
            }
        }

        return @parlist.grep( { $_ } );
    }

    sub contains(@array, $thing) {
        return ?( first { $_ === $thing }, @array );
    }

    sub toggle(@style_stack is rw, @promises is rw, $marker) {
        my $r;
        # RAKUDO: $elem ~~ @array
        if contains(@style_stack, $marker) {
            while @style_stack.end ne $marker {
                my $t = @style_stack.pop();
                @promises.push($t);
                $r ~= "</$t>";
            }
            $r ~= '</' ~ @style_stack.pop() ~ '>';
        }
        else {
            if contains(@promises, $marker) {
                @promises = grep { $_ !=== $marker }, @promises;
            }
            else {
                @style_stack.push($marker);
                $r ~= "<$marker>";
            }
        }
        return $r;
    }

    sub format_line($line is rw, :$link_maker, :$author) {
        my $partype = 'p';
        if $line ~~ /^ '==' (.*) '==' $/ {
            $partype = 'h2';
            $line = ~$/[0];
        }

        my $trimmed = $line;
        $trimmed .= subst( / ^ \s+ /, '' );
        $trimmed .= subst( / \s+ $ /, '' );

        my $cleaned_of_whitespace = $trimmed.trans( [ /\s+/ => ' ' ] );

        my $xml_escaped = $cleaned_of_whitespace.trans(
            [           '<', '>', '&', '\''   ] =>
            [ entities < lt   gt  amp  #039 > ]
        );

        my $result;
        my @style_stack;
        my @promises;

        $xml_escaped ~~ Tokenizer;
        for $/<token>.values -> $token {
            if $token<bold_marker> {
                $result ~= toggle(@style_stack, @promises, 'b');
            }
            elsif $token<italic_marker> {
                $result ~= toggle(@style_stack, @promises, 'i');
            }
            else {
                push @style_stack, @promises;
                $result ~= join '', map { "<$_>" }, @promises;
                @promises = ();
                $result ~= ~$token;
            }
        }

        $result ~= join '', map { "</$_>" }, reverse @style_stack;

        return sprintf '<%s>%s</%s>', $partype, $result, $partype;
    }

    sub format_paragraph($paragraph, :$link_maker, :$author) {
        # RAKUDO: This could use some ==>
        return
          merge_consecutive_paragraphs
          map { format_line($^line, :$link_maker, :$author) },
          $paragraph.split("\n");
    }

    method format($text, :$link_maker, :$author) {
        # RAKUDO: This could use some ==>
        return
          join "\n\n",
          map { format_paragraph($_, :$link_maker, :$author) },
          $text.split(/\n ** 2..*/);
    }
}

# vim:ft=perl6
