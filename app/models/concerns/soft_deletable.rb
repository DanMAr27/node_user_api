# app/models/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    include Discard::Model

    # Scope por defecto para excluir registros eliminados
    default_scope -> { kept }

    # Scopes adicionales
    scope :with_discarded, -> { unscope(where: :discarded_at) }
    scope :only_discarded, -> { unscope(where: :discarded_at).discarded }
  end

  # Métodos de instancia
  def active?
    !discarded?
  end

  def deleted?
    discarded?
  end

  # Alias para mantener consistencia semántica
  def soft_delete
    discard
  end

  def restore
    undiscard
  end
end
