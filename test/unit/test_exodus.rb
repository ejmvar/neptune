# Programmer: Chris Bunch (cgb@cs.ucsb.edu)


$:.unshift File.join(File.dirname(__FILE__), "..", "..", "lib")
require 'exodus'


require 'rubygems'
require 'flexmock/test_unit'


class TestExodus < Test::Unit::TestCase
  def test_exodus_job_good_params
    #params = {

    #}

    #expected = "output"
    #actual = exodus(params)
    #assert_equal(expected, actual.to_s)
    #assert_equal(expected, actual.stdout)
  end

  def test_exodus_job_bad_params
    # calling exodus with something that's not an Array or Hash should fail
    assert_raises(BadConfigurationException) {
      exodus(2)
    }

    # also, if we give exodus an Array, it had better be an array of Hashes
    assert_raises(BadConfigurationException) {
      exodus([2])
    }

    # calling exodus without specifying :clouds should fail
    assert_raises(BadConfigurationException) {
      exodus({})
    }

    # calling exodus with invalid clouds specified should fail
    assert_raises(BadConfigurationException) {
      exodus({:clouds_to_use => "not an acceptable value"})
    }

    # doing the same but with an array should also fail
    assert_raises(BadConfigurationException) {
      exodus({:clouds_to_use => ["not an acceptable value"]})
    }

    # giving an array of not strings should fail
    assert_raises(BadConfigurationException) {
      exodus({:clouds_to_use => [1, 2, 3]})
    }

    # giving not a string should fail
    assert_raises(BadConfigurationException) {
      exodus({:clouds_to_use => 1})
    }
  end

  def test_exodus_batch_params

  end
end
