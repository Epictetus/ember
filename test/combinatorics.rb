# Simple combinatorics library for Ruby 1.8, 1.9, and (hopefully) beyond.
#
# (the ISC license)
#
# Copyright 2007 Suraj N. Kurapati <sunaku@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
class Array
  unless method_defined? :enumeration
    ##
    # Returns all possible enumerations made from
    # sample_size number of items from this list.
    #
    # @param [Integer] sample_size
    #   The length of each enumeration.
    #
    # @param [Proc] sampler
    #   If given, each enumeration is passed to this block.
    #
    def enumeration(sample_size = self.length, &sampler)
      return [] if sample_size < 1

      results = []

      visitor = lambda do |parents|
        each do |child|
          result = parents + [child]

          if result.length < sample_size
            visitor.call result
          else
            yield result if block_given?
            results << result
          end
        end
      end

      visitor.call []
      results
    end
  end

  unless method_defined? :enumerations
    ##
    # Returns all possible enumerations of all possible lengths.
    #
    # @param [Proc] sampler
    #   If given, each enumeration is passed to this block.
    #
    def enumerations &sampler
      all_lengths_impl :enumeration, &sampler
    end
  end

  unless method_defined? :combination
    ##
    # Returns all possible combinations made from
    # sample_size number of items from this list.
    #
    # @param [Integer] sample_size
    #   The length of each combination.
    #
    # @param [Proc] sampler
    #   If given, each combination is passed to this block.
    #
    def combination(sample_size = self.length, &sampler)
      pnk_cnk_impl(sample_size, true, &sampler)
    end
  end

  unless method_defined? :combinations
    ##
    # Returns all possible combinations of all possible lengths.
    #
    # @param [Proc] sampler
    #   If given, each combination is passed to this block.
    #
    def combinations &sampler
      all_lengths_impl :combination, &sampler
    end
  end

  unless method_defined? :permutation
    ##
    # Returns all possible permutations made from
    # sample_size number of items from this list.
    #
    # @param [Integer] sample_size
    #   The length of each permutation.
    #
    # @param [Proc] sampler
    #   If given, each permutation is passed to this block.
    #
    def permutation(sample_size = self.length, &sampler)
      pnk_cnk_impl(sample_size, false, &sampler)
    end
  end

  unless method_defined? :permutations
    ##
    # Returns all possible permutations of all possible lengths.
    #
    # @param [Proc] sampler
    #   If given, each permutation is passed to this block.
    #
    def permutations &sampler
      all_lengths_impl :permutation, &sampler
    end
  end

  private

  ##
  # Returns results of the given method name for all possible sample sizes.
  #
  def all_lengths_impl method_name, &sampler
    results = []

    0.upto(length) do |i|
      results << __send__(method_name, i, &sampler)
    end

    results
  end

  ##
  # Common implementation for permutation and combination functions.
  #
  # @param [Integer] sample_size
  #   Maximum depth of traversal, at which point to stop
  #   further traversal and to start collecting results.
  #
  # @param [boolean] exclude_parents
  #   Prevent already visited vertices from being
  #   visited again in subsequent iterations?
  #
  def pnk_cnk_impl sample_size, exclude_parents
    results = []

    if sample_size >= 0 && sample_size < self.length
      ##
      # @param [#each] parents
      #   list of visited vertices, including the current vertex
      #
      # @param [#each] children
      #   list of unvisited vertices adjacent to current vertex
      #
      # @param [Integer] depth
      #   current depth of the traversal tree
      #
      visitor = lambda do |parents, children, depth|
        # traverse the graph until we reach the fringe
        # vertices (leaf nodes of the traversal tree)
        if depth < sample_size - 1
          children.each do |c|
            next_children = children - (exclude_parents ? parents : [c])
            next_parents  = parents + [c]
            next_depth    = depth + 1

            visitor.call next_parents, next_children, next_depth
          end
        else
          # now we have reached the fringe vertices
          children.each do |c|
            result = parents + [c]
            yield result if block_given?
            results << result
          end
        end
      end

      visitor.call [], self, 0
    end

    results
  end
end
